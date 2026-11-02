# Self-hosted runners for autoware-localrepo

`.github/workflows/localrepo.yml` builds, tests and releases the local
repository on two self-hosted runners. Each one is a container started from
the image in this directory.

| Host | Labels | Builds |
|---|---|---|
| x86 machine | `autoware-localrepo`, `localrepo-amd64` | amd64 |
| arm64 server | `autoware-localrepo`, `localrepo-arm64`, `localrepo-jp62` | arm64 (SBSA) and jp62 (Jetson) |

There is no Jetson in the loop. The arm64 server builds the jp62 packages
natively from the JetPack builder image, and runs their install test the same
way. Running the test does not need a GPU.

## How it fits together

```
host
├── docker daemon ◄───────────── /var/run/docker.sock (mounted)
│     ├── colcon2deb builder containers
│     └── localrepo install-test containers
└── $LOCALREPO_RUNNER_ROOT  (mounted at the same path)
      ├── runner-config/   registration (.runner, .credentials*)
      ├── _work/           checkout, Autoware source, build trees (kept)
      ├── venv/            colcon2deb, one venv per pinned commit
      ├── out/<run id>/    debs waiting for the upload job
      └── tmp/
runner container (this image): actions runner, just, dpkg tools, docker CLI
```

Two things here are not obvious.

- **The runner directory is mounted at the same path inside and outside the
  container.** colcon2deb runs its builds in containers on the host's Docker
  daemon, and passes bind mounts like `-v <workspace>:/workspace`. The host
  daemon resolves those paths on the host. If the container saw the directory
  under another name, colcon2deb would mount empty directories. The entrypoint
  checks this before it registers.
- **The build trees persist.** `_work` survives jobs and container restarts,
  so colcon2deb rebuilds only what changed. The first build of each version
  and platform takes hours; later ones are much shorter. Budget about 100 GB of
  disk per version and platform, plus the builder images in Docker's own
  storage.

## Security

The container holds the host's Docker socket, which means **anyone who can run
a job on this runner has root on the host.** That is the price of colcon2deb
starting containers. What keeps it contained:

- The workflow triggers only on tag pushes and `workflow_dispatch`, which both
  need write access to the repository. It never runs on `pull_request`.
- autoware-localrepo is public, so a fork's pull request could add a new
  workflow that targets these labels. In the repository's Actions settings, set
  *Fork pull request workflows* to **Require approval for all external
  contributors**, and never approve a run that touches `.github/workflows/`
  without reading it.
- For a stronger boundary, register the runners at the organization level, in
  a runner group restricted to this repository and to the workflow
  `.github/workflows/localrepo.yml`. Then GitHub refuses to schedule any other
  workflow on them.
- Use a host that does not hold anything else worth protecting, or accept that
  a repository writer can reach it.

The container itself runs as an unprivileged user, with all capabilities
dropped and `no-new-privileges` set. Those settings limit what a job can do
inside the container. Through the socket, it can still do anything on the host.

## Setting up a host

Requirements: Docker, about 300 GB free, and `gh` logged in as a repository
admin (used only to mint registration tokens). On the x86 host, nothing more.
On the arm64 server, nothing more either: every build is native.

```bash
git clone https://github.com/NEWSLabNTU/autoware-localrepo.git
cd autoware-localrepo
ci/runner/runner.sh build       # image for this machine's architecture
ci/runner/runner.sh register    # registers, then restarts without the token
ci/runner/runner.sh status
```

The container restarts with Docker (`--restart unless-stopped`), so it comes
back after a reboot. If its startup checks fail (no Docker, path mismatch, less
than 100 GB free) it does not register; it logs why, waits 15 minutes and tries
again. Watch it with `ci/runner/runner.sh logs`.

Override the defaults with environment variables:

| Variable | Default |
|---|---|
| `LOCALREPO_RUNNER_ROOT` | `$HOME/autoware-localrepo-runner` |
| `RUNNER_LABELS` | by architecture, see the table above |
| `RUNNER_NAME` | `<hostname>-localrepo` |
| `GH_REPO` | `NEWSLabNTU/autoware-localrepo` |

After changing the Dockerfile, run `build` and then `run`. The registration is
kept in `runner-config/`, so no new token is needed. GitHub stops accepting
runners that fall too far behind; when it does, bump `RUNNER_VERSION` in the
Dockerfile and rebuild.

To retire a host: `ci/runner/runner.sh unregister`. The build trees stay under
`$LOCALREPO_RUNNER_ROOT/_work` until you delete them.

## Running a build

- **Build and test only:** Actions → localrepo → Run workflow, pick the
  version and platforms, leave the release tag empty.
- **Release:** push a tag such as `1.9.0-2`, or run the workflow with a release
  tag. The workflow creates a **draft** release, the per-platform jobs attach
  their debs, and a final job writes `SHA256SUMS.txt` from the digests GitHub
  records. Check the draft, then publish it by hand.

The `autoware-data` debs are the same on every platform, so whichever platform
finishes first attaches them. A version's changelog revision
(`debian/changelog` of each package) is not derived from the tag; bump it in a
commit before tagging, as for a manual release.

The colcon2deb commit is pinned by `COLCON2DEB_REF` in the workflow. Bump it
deliberately: a new colcon2deb can change every package.
