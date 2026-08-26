# Autoware 1.9.0 — build state and how to resume

Checkpoint written 2026-08-20. The amd64 packaging is complete and committed;
the ROS build was stopped part-way through the final phase because the build
host ran out of disk on `/`. Nothing is broken — resuming is a short job.

## Status: jp62 E2E COMPLETE (2026-08-26)

`1.9.0/arm64/` — the generic-arm64 directory prepared on 2026-08-23 — was a
copy of the amd64 tree with only the acados tera-renderer URL and the acados
package architecture changed. It kept the amd64 base image (CUDA 12.8 /
TensorRT 10.8, which JetPack 6.2 does not ship), the amd64 rosdep list, the
amd64 setup-prerequisites.sh, and an amd64 test harness. It has been replaced
by `1.9.0/jp62/`, rebuilt from the 1.7.1/jp62 recipe on
`nvcr.io/nvidia/l4t-tensorrt:r10.3.0-devel`.

The full chain now passes on a **native arm64 host** (80 cores, 498 GB RAM —
no QEMU, so the ASLR and `CMAKE_THREAD_LIBS_INIT` cross-build workarounds are
deliberately absent):

| Step | Result |
|------|--------|
| `just ros` | 488/488, Status SUCCESS |
| `just meta` | 10 debs; data split vision 830 MB / perception3d 1.02 GB / planning 553 MB |
| `just localrepo` | **494** bundled packages, `autoware-localrepo-1-9-0_1.9.0-1jetpack62_all.deb` (203 MB) |
| `just test` | PASS — autoware-full installs, 345 Autoware packages visible to ros2 |
| `just release` | 4 assets staged, largest 1.02 GB |

### Four bugs fixed on the way; two of them are amd64 bugs too

**jp62-only — CUDA/toolchain skew.** JetPack 6.2 pins CUDA 12.6 on Ubuntu
22.04; the amd64 builder is on CUDA 12.8 with GCC-13-era wheels, so neither
of these could surface there:

1. `cuda_blackboard` calls `cudaStreamGetDevice()`, added in CUDA 12.8. It is
   a leaf much of perception depends on, so pass 1 stopped at 138/488 with 34
   aborted and 315 unprocessed. `patches/0001-cuda_blackboard-cuda-12.6-compat.patch`
   guards it with `#if CUDART_VERSION >= 12080` and falls back to
   `cudaGetDevice()`. **Not yet upstreamed** — `cuda_blackboard` is a
   submodule of a submodule, so this must be re-applied after a fresh clone
   until it is forked to NEWSLabNTU and the pins move.
2. casadi 3.8.0's aarch64 wheel needs `GLIBCXX_3.4.32`; Ubuntu 22.04 tops out
   at 3.4.30, so `autoware_path_optimizer`'s acados codegen died on import.
   Pinned `casadi==3.7.2` in the Dockerfile (upstream's
   `ansible/roles/acados` pins nothing, and the amd64 wheel of the same
   version links an older toolchain).

**Both architectures — packaging, found by `just test`.** Now fixed in
**both** `1.9.0/jp62/` and `1.9.0/amd64/`; the amd64 side is code-complete but
**unverified** — it needs `just ros` (rebuilds `autoware_core_planning` only,
the rest fingerprint-cached), then `just localrepo` and `just test`:

3. `autoware-acados-1-9-0` was **never bundled into the localrepo**. The
   `localrepo` recipe's meta-package copy list omits it, so the deb that
   80282eaf added to close the acados runtime gap was built but never
   shipped, and `apt install autoware-full` could not satisfy the `Depends:`
   it introduced. The old "493 bundled packages" is 487 ROS + 6 meta. Now 494.
4. `autoware_core_planning` depended on
   `ros-humble-autoware-mission-planner-1-9-0`, which the same recipe
   deliberately drops as superseded — an unsatisfiable dep. 1.7.1 had an
   override for exactly this; 1.9.0 never got one. Added
   `debian-overrides/autoware_core_planning` pointing at
   `-mission-planner-universe-`. It is the only deb of the 488 that
   referenced the dropped name.

Also worth knowing: the inherited claim that `python3-torch` is unavailable on
arm64 is **wrong** — jammy/universe carries 1.8.1-4 and rosdep installs it in
phase 3 regardless. Left commented out in `rosdep-packages.txt` only because
that file is a Docker build input, and touching it rebuilds the image and
invalidates every colcon2deb fingerprint.

Two ML archives (`tensorrt_rtmdet_onnx_models.tar.gz`, `tensorrt_bevdet.tar.gz`)
arrived byte-complete but gzip-corrupt from aria2's 8-way ranged fetches
against a throttling S3 endpoint. `gzip -t` catches it; a single-stream
`curl -C -` retry loop fixes it. Worth a `gzip -t` sweep before `just meta` on
a slow link.

## Status: amd64 E2E COMPLETE (2026-08-21)

The full chain finished on the original host: `just ros` (488/488 ROS debs,
Status SUCCESS) → `just meta` → `just localrepo` (493 bundled packages,
`autoware-localrepo-1-9-0_1.9.0-1ubuntu2204_all.deb`).

What changed since the 2026-08-20 checkpoint below:

- **debian-overrides pruned from 488 frozen dirs to 19 targeted ones.**
  colcon2deb no longer needs bloom output frozen as overrides (it
  regenerates and fingerprints per package), and a full freeze goes stale
  on any version/prefix change. The 19 kept are real patches: 17 CUDA
  packages with LTO disabled (fatbin symbol conflicts) and Replaces:
  fields for autoware_mission_planner_universe and
  autoware_overlay_rviz_plugin (open item 2 below — resolved).
- **Workspace repinned** to NEWSLabNTU/autoware_universe `1.9.0-patches`:
  the acados codegen custom commands raced under `make -j` (multi-output
  rule runs the generator twice; FileExistsError) — serialized with a
  stamp file. 1.5.0-ws similarly repinned for the system_monitor
  missing-include fix.
- **Dockerfile acados block finalized**: full ansible layout at
  /opt/acados (source, venv, tera renderer) plus a /usr/local install so
  find_package(acados) works in the debian/rules pass, whose generated
  rules overwrite CMAKE_PREFIX_PATH.
- **Open item 1 RESOLVED**: acados now ships as its own deb
  (`packages/autoware-acados-1-9-0/`, acados v0.5.3 built from the pinned
  upstream tag into /opt/autoware/1.9.0 with blasfeo/hpipm/qpOASES), and
  debian-overrides add `Depends: autoware-acados-1-9-0` to
  autoware_path_optimizer and autoware_trajectory_optimizer. Bundled in
  the localrepo (493 packages).
- colcon2deb grew skip_tests support, prerequisite checks, and a
  writable install prefix in the container (autoware_system_design_examples
  writes deployments into the prefix during dh_auto_build).

Remaining open items:

- **Verify the amd64 packaging fixes** (3 and 4 above, applied 2026-08-26 but
  not built). `just ros` → `just localrepo` → `just test`. Expect 487 cached +
  1 rebuilt, and the bundled count to go 493 → 494. The two `debian-overrides`
  sets are now byte-identical across amd64 and jp62, and the two justfiles
  differ only in their header comment.
- **Optional, not applied to amd64: pin casadi.** jp62 had to pin
  `casadi==3.7.2` (see 2 above). amd64 floats to latest and currently works,
  so this is latent rather than broken — a future casadi release could break
  it the same way. Pinning is a Dockerfile change, which changes the image ID,
  which invalidates *every* colcon2deb fingerprint and forces a full
  repackaging pass. Not worth doing on its own; fold it into the next amd64
  image rebuild.
- **Upstream the cuda_blackboard patch** (fork to NEWSLabNTU, `1.9.0-patches`,
  repin the submodule) so jp62 stops needing a manual `git apply`.
- **`autoware-maps` is now a dependency of `autoware-full` — in 1.9.0 only.**
  Previously maps were opt-in in 1.5.0, 1.7.1 and 1.9.0 alike, which left the
  documented `map_path` (`/opt/autoware/<version>/share/autoware_maps/`) empty
  after a default install. Fixed for 1.9.0 on both arches and verified on
  jp62: `apt install autoware-full-1-9-0` now pulls `autoware-maps-1-9-0`
  (+13 MB) and both `sample-map-planning` and `sample-map-rosbag` land at that
  path. **1.5.0 and 1.7.1 were left alone** — both are already published, so
  changing what `autoware-full` installs would alter released packages; decide
  separately whether to backport or amend their docs.
- rosbag-sample suffix backports to 1.5.0/1.7.1.

---

# Original checkpoint (2026-08-20, superseded)

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
