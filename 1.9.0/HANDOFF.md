# Autoware 1.9.0 — build state and how to resume

Checkpoint written 2026-08-20. The amd64 packaging is complete and committed;
the ROS build was stopped part-way through the final phase because the build
host ran out of disk on `/`. Nothing is broken — resuming is a short job.

## Where the build got to

`just ros` (colcon2deb 0.4.1) on the third attempt:

| Phase | Result |
|-------|--------|
| 1 Prepare working directories | ok |
| 2 Copy source files | ok |
| 3 Install dependencies | ok |
| 4 **Compile packages** | **ok — 10m 38s, all packages** |
| 5 Generate rosdep list | ok |
| 6 Create package list | ok |
| 7 **Generate Debian metadata** | **ok — 488 dirs, committed** |
| 8 Build .debs | **stopped after 21 of 488** |

Only phase 8 remains. It is I/O-bound packaging, not compilation.

## Resuming

The compiled workspace lives in `1.9.0/amd64/build/` (~12 GB) and is **not** in
git. On a fresh host it must be rebuilt from scratch:

```bash
cd 1.9.0/amd64
just ros            # phases 1-8; phase 4 is the long one (~11 min warm, longer cold)
```

On the original host, where `build/` still exists, colcon2deb fingerprints
completed work, so re-running `just ros` skips recompilation and resumes at
phase 8.

Disk: `build/` reaches ~12 GB, and the builder Docker image is ~30 GB. Budget
~50 GB free on the filesystem backing `/var/lib/docker` plus ~15 GB where the
repo lives.

## Base image: do not rely on `docker pull`

ghcr throttles a single connection to ~1.4 MB/s. `autoware-base:cuda-latest` is
4.69 GiB, of which one CUDA layer is 4.47 GB. Docker uses one connection per
blob, has a fixed retry budget, and restarts a failed blob from zero — it never
completed here, failing at ~80% every attempt. The other 23 layers always
succeeded.

Try `docker pull` first on a new host; if that one layer stalls, the workaround
is to fetch blobs with aria2c (the CDN at `pkg-containers.githubusercontent.com`
serves unauthenticated ranged GETs, so `-x16` gives ~9.5 MB/s and resumes),
verify each blob's sha256 against the manifest, assemble a **legacy
docker-save** archive and `docker load` it. Docker 28 without the containerd
image store cannot load an OCI layout — it fails looking for `blobs/json`.

## Open items

1. **acados runtime dependency (verify before release).** In 1.7.1 acados was a
   workspace package installed into `/opt/autoware/1.7.1`, so it shipped inside
   the debs. In 1.9.0 it was dropped from `repositories/autoware.repos` and now
   exists only at `/opt/acados` in the builder image. The generated
   `ros-humble-autoware-path-optimizer-1-9-0` control file lists **no** acados
   dependency, so the deb likely links `/opt/acados/lib/libacados.so`, a path
   absent on user machines. Check the built deb with `objdump -p ... | grep
   -E 'NEEDED|RPATH|RUNPATH'`. If confirmed, acados must ship as its own package
   (e.g. `autoware-acados-1-9-0`) and `autoware_path_optimizer` /
   `autoware_trajectory_optimizer` must depend on it.

2. **Manual debian-overrides patches.** None applied yet. 1.7.1 needed three:
   `bevdet_vendor` LTO disable, `autoware_core_planning` depending on
   mission-planner-universe rather than the superseded mission-planner, and
   stripped deps in eight jp62 launch packages. Phase 8 will reveal which
   1.9.0 equivalents are needed.

3. **`just meta` needs `debhelper`** on the host (`sudo apt install debhelper`).

4. **jp62 not started.** Only `1.9.0/amd64/` exists.

5. **`autoware-rosbag-sample` lacks a version suffix in 1.5.0 and 1.7.1.** Fixed
   for 1.9.0 only; the older versions still share one package name across
   releases.

## Things already settled (don't re-litigate)

- **autoware-data is split into three topic packages.** One deb measured
  2.24 GiB, over GitHub's 2 GiB asset limit. Now
  `autoware-data-{vision,perception3d,planning}-1-9-0` at 791 / 974 / 528 MiB
  plus a metapackage `autoware-data-1-9-0`. `groups.yaml` holds the map and
  `genpkg.py` aborts if a future version adds an unmapped model directory.
- **acados is required.** Two packages call `find_package(acados REQUIRED)`, and
  the codegen step needs `/opt/acados/.venv/bin/python3` by absolute path.
- **Both `genpkg.py` scripts take `--suffix` / `--install-dir`.** The old manual
  "restore the version suffix after regenerating" step is obsolete.
- **Beware `grep` in Claude Code shells here.** It is a shell function that
  silently returns nothing for recursive searches; use `/usr/bin/grep -r`. An
  earlier wrong conclusion about acados came from this.

## Upstream reference points

- Workspace branch: `NEWSLabNTU/autoware` @ `1.9.0-ws` (tag 1.9.0 + 32 submodules)
- Version pins moved: `amd64.env`/`arm64.env` are gone; see
  `ansible/roles/{cuda,tensorrt,spconv,acados}/defaults/main.yaml`.
  humble + x86_64 resolves to CUDA 12.8, TensorRT 10.8.0.43-1+cuda12.8,
  spconv 2.3.8, cumm 0.5.3, acados v0.5.3, tera_renderer v0.2.0.
