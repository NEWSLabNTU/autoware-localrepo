# Autoware 1.5.0 arm64 Server Build

This directory contains the colcon2deb configuration for building Autoware 1.5.0
ROS packages for **generic arm64 servers** (SBSA): an aarch64 host with a
discrete NVIDIA GPU, such as Grace Hopper (GH200), an Ampere Altra with an
A100/H100, or any other Ubuntu 22.04 arm64 machine running NVIDIA's SBSA CUDA
stack. It is not for Jetson; JetPack has its own build in `../jp62/`.

## How it differs from amd64

It is the amd64 recipe with the changes below, and nothing else. The
debian-overrides are amd64's, plus the LTO disables that `../jp62/` carries for
nine CUDA packages (`optimize=-lto` in `debian/rules`); disabling LTO is
harmless where it was not needed, and the fatbin symbol clash it avoids is not
specific to Jetson. The workspace
submodule is pinned to the same commit as `../amd64/source`.

| | amd64 | arm64 (this dir) |
|---|---|---|
| Base image | `autoware-base` (CUDA 12.4) | same tag; its manifest is multi-arch |
| TensorRT | 10.8.0.43-1+cuda12.8 | **10.3.0.26-1+cuda12.5** |
| GPU kernels | sm_75/86/87/89 (+101/120 on CUDA 12.8) | the same **plus sm_80 and sm_90**, and compute_75 PTX |
| Localrepo version suffix | `ubuntu2204` | `ubuntu2204sbsa` |

**TensorRT 10.3.** NVIDIA's `ubuntu2204/sbsa` apt repository stops at TensorRT
10.3.0.26, so the amd64 pin does not exist for this architecture. It is also
what Autoware's own `arm64.env` / ansible role selects for aarch64 Humble.

**sm_80 and sm_90.** Every CUDA package hardcodes its `-gencode` list in its
CMakeLists. That list covers Turing, consumer Ampere, Orin and Ada, not A100
(sm_80) or H100/GH200 (sm_90), and the PTX it embeds is for a newer
architecture, which the driver cannot JIT backwards. Without the extra kernels
those packages install fine and then fail at their first kernel launch with
`no kernel image is available for execution on the device`. The Dockerfile
sets `NVCC_APPEND_FLAGS` so that nvcc adds both architectures to every
compile, in colcon's pass and in `debian/rules` alike. No package source is
patched.

It also adds `compute_75` PTX. A package that sets no architecture of its own
would otherwise lose nvcc's default (compute_52 PTX, which JITs anywhere) the
moment any `-gencode` is given, and run on sm_80/sm_90 only; with the PTX it
still runs on a T4G (AWS g5g) or an RTX card.

**Version suffix.** The localrepo deb is `Architecture: all`, so without a
distinct suffix its file name would collide with the amd64 one in a release.

Build natively on an arm64 host (`config.yaml` sets `platform: linux/arm64`).

### Installing

```bash
sudo dpkg -i autoware-localrepo-1-5-0_*ubuntu2204sbsa_all.deb
sudo /usr/share/autoware/1.5.0/setup-prerequisites.sh   # ROS 2, CUDA 12.4 libs, cuDNN, TensorRT 10.3, SpConv (arm64-sbsa)
sudo apt update
sudo apt install autoware-full-1-5-0
sudo /usr/share/autoware/1.5.0/activate-dds-config.sh
```

The prerequisites script refuses to run on a Jetson.

## Configuration

### Package Naming

Packages are built with `-1-5-0` suffix to allow multiple Autoware versions to coexist:
- Example: `ros-humble-autoware-core-1-5-0` instead of `ros-humble-autoware-core`

This is configured in `config.yaml`:
```yaml
build:
  package_suffix: "1-5-0"
```

### Install Prefix

Packages install to `/opt/autoware/1.5.0` instead of the default `/opt/ros/humble`.

## Patches

### Replaces for Conflicting Files

Some packages have been renamed or merged but still install files to the same paths. This causes dpkg conflicts during installation. The fix is to add `Replaces:` to the new package's `debian/control`.

**Fix**: Add `Replaces:` field after the `Depends:` line in `debian/control`:

| Package | Replaces | Reason |
|---------|----------|--------|
| `autoware_mission_planner_universe` | `ros-humble-autoware-mission-planner-1-5-0` | Supersedes autoware_mission_planner |
| `autoware_overlay_rviz_plugin` | `ros-humble-autoware-mission-details-overlay-rviz-plugin-1-5-0` | Absorbed mission_details_overlay functionality |

### LTO Disable for CUDA Packages

Ubuntu 22.04 enables LTO (Link Time Optimization) by default via `dpkg-buildflags`. This conflicts with CUDA's fatbin symbols during linking:

```
Error: symbol 'fatbinData' is already defined
lto-wrapper: fatal error: make returned 2 exit status
```

**Fix**: Add the following to the top of `debian/rules` (after the dh-make comment block):

```makefile
# Disable LTO - causes conflicts with CUDA fatbin symbols
export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto
```

**Affected packages (17 total)**:
- autoware_bevfusion
- autoware_camera_streampetr
- autoware_cuda_pointcloud_preprocessor
- autoware_cuda_utils
- autoware_lidar_centerpoint
- autoware_lidar_frnet
- autoware_lidar_transfusion
- autoware_probabilistic_occupancy_grid_map
- autoware_ptv3
- autoware_tensorrt_bevdet
- autoware_tensorrt_bevformer
- autoware_tensorrt_classifier
- autoware_tensorrt_common
- autoware_tensorrt_plugins
- autoware_tensorrt_yolox
- bevdet_vendor
- trt_batched_nms

## Regenerating debian-overrides

If you need to regenerate the debian-overrides directory:

```bash
# Delete existing overrides
rm -rf debian-overrides/*

# Regenerate with colcon2deb
colcon2deb --workspace source --config config.yaml --generate-debian-only

# Re-apply patches:
# 1. CUDA LTO fixes - add to debian/rules (see LTO section above)
# 2. Replaces fixes - add to debian/control (see Replaces section above)
```

## Building

```bash
# Build all packages
just ros

# Or manually
colcon2deb --workspace source --config config.yaml
```
