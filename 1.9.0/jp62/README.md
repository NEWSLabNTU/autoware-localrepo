# Autoware 1.9.0 JetPack 6.2 (arm64) Build

colcon2deb configuration for building the Autoware 1.9.0 ROS packages for
Jetson devices running **JetPack 6.2** (L4T r36.4.x, CUDA 12.6, cuDNN 9.3,
TensorRT 10.3).

Build natively on an arm64 host. Cross-building from amd64 works through QEMU
user-mode emulation but is very slow and needs the workarounds in
`../../BUILDING.md` (ASLR disable, `--credential yes` binfmt registration).

## Configuration

### Base image

`nvcr.io/nvidia/l4t-tensorrt:r10.3.0-devel` — the JetPack 6.2 development image.
This is *not* the `autoware-base:cuda-latest` image used by `../amd64/`: the
Jetson target does not follow the CUDA 12.8 / TensorRT 10.8 pins in
`ansible/roles/{cuda,tensorrt}/defaults/main.yaml`, because JetPack 6.2 ships
CUDA 12.6 / TensorRT 10.3 and that is what the on-device runtime provides.
spconv 2.3.8 / cumm 0.5.3 and acados v0.5.3 / tera_renderer v0.2.0 do apply,
using the arm64 artifacts.

### Package naming

Packages are built with the `-1-9-0` suffix so multiple Autoware versions can
coexist — e.g. `ros-humble-autoware-core-1-9-0`. Configured in `config.yaml`:

```yaml
build:
  package_suffix: "1-9-0"
```

### Install prefix

Packages install to `/opt/autoware/1.9.0` instead of `/opt/ros/humble`.

## JetPack-specific build details

These are the deltas from the amd64 build; each has bitten a previous release.

| Item | Why |
|------|-----|
| L4T OpenCV 4.8.0 removed, Ubuntu's 4.5.4 pinned via `opencv-preferences` | L4T ships OpenCV outside APT; ROS `cv_bridge` links Ubuntu's version and CMake fails on the mismatched `libopencv_core.so.4.8.0` |
| L4T CMake 3.14.4 removed from `/usr/local/bin`, Ubuntu's 3.22.1 installed | Autoware needs 3.16+; 3.22 still has a working `FindCUDA` module |
| `CUDAARCHS=87` | Orin. Avoids `CUDA_ARCHITECTURES native`, which needs a GPU present at image-build time |
| `python3-torch` commented out of `rosdep-packages.txt` | Inherited from 1.7.1, where the comment claims it is unavailable on arm64. That is **wrong** — jammy/universe arm64 carries `python3-torch` 1.8.1-4, and rosdep installs it during phase 3 regardless. Left commented only because `rosdep-packages.txt` is a Docker build input: uncommenting it rebuilds the image and invalidates every colcon2deb fingerprint, for no gain beyond baking it into the image a phase earlier |
| `libvtk9-dev`, `libvtk9-qt-dev`, `ros-humble-cudnn-cmake-module`, `ros-humble-pacmod3-msgs` added to `rosdep-packages.txt` | Not pulled in transitively on arm64 |
| `nvidia-l4t-core`, `nvidia-l4t-cuda`, `nvidia-l4t-dla-compiler` from the r36.4 APT repos | CUDA driver stubs and the DLA compiler |
| spconv/cumm installed from `autowarefoundation/spconv_cpp` `*_arm64-jetson.deb` | `autoware_tensorrt_plugins` links `spconv::spconv` |
| acados tera renderer: `t_renderer-v0.2.0-linux-arm64` | arm64 binary, not the amd64 one |
| No `CMAKE_THREAD_LIBS_INIT` override in `/colcon2deb-setup.sh` | That workaround exists only for QEMU cross-builds, where CMake's `FindThreads` compile-and-run test fails. Re-add it if you cross-build |

## Workspace source patches (`patches/`)

JetPack 6.2 ships CUDA 12.6, while the amd64 builder image is on CUDA 12.8, so
the amd64 build never exercised the 12.6 ceiling. One workspace package uses a
CUDA 12.8-only API:

| Patch | Package | Problem |
|-------|---------|---------|
| `0001-cuda_blackboard-cuda-12.6-compat.patch` | `src/universe/external/cuda_blackboard` | `cudaStreamGetDevice()` was introduced in CUDA 12.8. On 12.6 the build fails with `error: 'cudaStreamGetDevice' was not declared in this scope`. The patch guards the call with `#if CUDART_VERSION >= 12080` and falls back to `cudaGetDevice()`, which returns the same id here — both streams are created on the current device immediately above the call |

`cuda_blackboard` is a leaf that much of the perception stack depends on, so the
failure cascades: one `Failed <<<` plus a long tail of `Aborted <<<`.

Apply before building on a fresh checkout:

```bash
git -C source/src/universe/external/cuda_blackboard apply \
    ../../../../../patches/0001-cuda_blackboard-cuda-12.6-compat.patch
```

**To upstream**: fork `autowarefoundation/cuda_blackboard` to NEWSLabNTU, land
this on a `1.9.0-patches` branch, repin the submodule in
`NEWSLabNTU/autoware` `1.9.0-ws`, then bump the localrepo submodule pointer —
the same flow used for `autoware_universe` (see the root `CLAUDE.md`). Until
that happens the patch has to be re-applied by hand after every fresh clone.

## Patches (debian-overrides)

`debian-overrides/` holds 19 targeted patches, not a frozen copy of every
package's bloom output — colcon2deb regenerates and fingerprints debian
metadata itself, and a full freeze goes stale on any version or prefix change.

### Replaces for conflicting files

Some packages were renamed or merged upstream but still install to the same
paths, which trips dpkg on upgrade. Fixed by adding `Replaces:` after the
`Depends:` line in `debian/control`:

| Package | Replaces | Reason |
|---------|----------|--------|
| `autoware_mission_planner_universe` | `ros-humble-autoware-mission-planner-1-9-0` | Supersedes autoware_mission_planner |
| `autoware_overlay_rviz_plugin` | `ros-humble-autoware-mission-details-overlay-rviz-plugin-1-9-0` | Absorbed mission_details_overlay functionality |

`autoware_path_optimizer` and `autoware_trajectory_optimizer` additionally
carry `Depends: autoware-acados-1-9-0` — acados is no longer a workspace
package in 1.9.0, so it ships as its own deb (`packages/autoware-acados-1-9-0/`).

### LTO disable for CUDA packages

Ubuntu 22.04 turns on LTO through `dpkg-buildflags`, which collides with CUDA's
fatbin symbols at link time:

```
Error: symbol 'fatbinData' is already defined
lto-wrapper: fatal error: make returned 2 exit status
```

Fixed by adding this to the top of `debian/rules`:

```makefile
# Disable LTO - causes conflicts with CUDA fatbin symbols
export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto
```

Affected packages (17): `autoware_bevfusion`, `autoware_camera_streampetr`,
`autoware_cuda_pointcloud_preprocessor`, `autoware_cuda_utils`,
`autoware_lidar_centerpoint`, `autoware_lidar_frnet`,
`autoware_lidar_transfusion`, `autoware_probabilistic_occupancy_grid_map`,
`autoware_ptv3`, `autoware_tensorrt_bevdet`, `autoware_tensorrt_bevformer`,
`autoware_tensorrt_classifier`, `autoware_tensorrt_common`,
`autoware_tensorrt_plugins`, `autoware_tensorrt_yolox`, `bevdet_vendor`,
`trt_batched_nms`.

## Regenerating debian-overrides

```bash
# Regenerate with colcon2deb (runs through phase 7, skips the .deb build)
colcon2deb --workspace source --config config.yaml \
    --skip-rosdep-install --skip-copy-src --skip-gen-rosdep-list \
    --skip-colcon-build --skip-build-deb

# Harvest the generated debian/ dirs for the packages you actually patch
cp -r build/packaging/<pkg>/debian debian-overrides/<pkg>/

# Re-apply the patch (LTO or Replaces, see above), then commit only that delta.
```

## Building

```bash
just ros         # ROS .debs via colcon2deb
just meta        # meta-packages (needs debhelper on the host)
just localrepo   # bundled APT repo package
just all         # all three, in order

just test        # install test in a clean L4T container
just release     # stage packages/release/ for GitHub upload
```

Monitor progress:

```bash
tail -f build/logs/latest/phases/phase4_build_src.log
cat build/logs/latest/reports/summary.txt
```
