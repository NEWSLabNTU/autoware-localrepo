# Autoware 2.1.0 JetPack 6.2 (arm64) Build

colcon2deb configuration for building the Autoware 2.1.0 ROS packages for
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

Packages are built with the `-2-1-0` suffix so multiple Autoware versions can
coexist — e.g. `ros-humble-autoware-core-2-1-0`. Configured in `config.yaml`:

```yaml
build:
  package_suffix: "2-1-0"
```

### Install prefix

Packages install to `/opt/autoware/2.1.0` instead of `/opt/ros/humble`.

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
| `ros-humble-rmw-cyclonedds-cpp` installed, `ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` | New in 2.1.0. Unset, the build falls back to Fast DDS, whose `fastrtps-config.cmake` runs `find_package(TinyXML2)` after 2.1.0's dependency order has put mrt_cmake_modules' `FindTinyXML2` on the module path; that sets `TinyXML2_LIBRARY` but not `TINYXML2_LIBRARY`, and tinyxml2_vendor stops `autoware_lidar_marker_localizer`'s configure ("Unable to extract the library file path from"). Upstream's own base image sets the same ENV |

## Workspace source patches (`patches/`)

JetPack 6.2 ships CUDA 12.6, while the amd64 builder image is on CUDA 12.8, so
the amd64 build never exercised the 12.6 ceiling. One workspace package uses a
CUDA 12.8-only API:

| Patch | Package | Problem |
|-------|---------|---------|
| `0001-cuda_blackboard-cuda-12.6-compat.patch` | `src/core/cuda/cuda_blackboard` | `cudaStreamGetDevice()` was introduced in CUDA 12.8. On 12.6 the build fails with `error: 'cudaStreamGetDevice' was not declared in this scope`. The patch guards the call with `#if CUDART_VERSION >= 12080` and falls back to `cudaGetDevice()`, which returns the same id here — both streams are created on the current device immediately above the call |

`cuda_blackboard` is a leaf that much of the perception stack depends on, so the
failure cascades: one `Failed <<<` plus a long tail of `Aborted <<<`.

Apply before building on a fresh checkout:

```bash
git -C source/src/core/cuda/cuda_blackboard apply \
    ../../../../../patches/0001-cuda_blackboard-cuda-12.6-compat.patch
```

In 2.1.0, cuda_blackboard moved from `src/universe/external/` to
`src/core/cuda/` (0.5.0) and still calls `cudaStreamGetDevice`, so the patch is
still needed; it applies unchanged at the new path. It is kept here as a jp62
file rather than on a fork, since only the CUDA 12.6 target needs it. It has to
be re-applied by hand after every fresh clone.

## Patches (debian-overrides)

`debian-overrides/` holds 25 targeted patches, the 1.9.0 deltas ported to
2.1.0's bloom output by `scripts/port-overrides.py`, whose header lists them.
The set is the same as `../arm64/` and `../amd64/` (bloom's output does not
differ per architecture):

| Delta | Packages |
|---|---|
| LTO off in `debian/rules` (CUDA fatbin: `symbol 'fatbinData' is already defined`) | 16 CUDA packages (1.9.0's 17 less `trt_batched_nms`, gone in 2.1.0) |
| agnocast pinned to the system glog | `agnocastlib`, `agnocast_components`, `agnocast_e2e_test`, `agnocast_sample_application` (new on jp62 in 2.1.0: `dpkg-shlibdeps: error: cannot find library libglog.so.1`) |
| `Depends: autoware-acados-2-1-0` (they link libacados) | `autoware_path_optimizer`, `autoware_trajectory_modifier` |
| `Replaces:` | `autoware_mission_planner_universe`, `autoware_overlay_rviz_plugin` |
| core_planning depends on mission-planner-universe | `autoware_core_planning` |

To regenerate them, run `just ros` once with an empty `debian-overrides/`, then
`scripts/port-overrides.py 2.1.0/jp62`.

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
