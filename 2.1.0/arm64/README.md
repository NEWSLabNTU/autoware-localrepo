# Autoware 2.1.0 arm64 Server Build

This directory contains the colcon2deb configuration for building Autoware 2.1.0
ROS packages for **generic arm64 servers** (SBSA): an aarch64 host with a
discrete NVIDIA GPU, such as Grace Hopper (GH200), an Ampere Altra with an
A100/H100, or any other Ubuntu 22.04 arm64 machine running NVIDIA's SBSA CUDA
stack. It is not for Jetson; JetPack has its own build in `../jp62/`.

## How it differs from amd64

It is the amd64 recipe with the changes below, and nothing else, plus two
for acados: the builder fetches the `linux-arm64` tera renderer, and
`packages/autoware-acados-2-1-0` is `Architecture: any` so it builds natively. The workspace
submodule is pinned to the same commit as `../amd64/source`.

| | amd64 | arm64 (this dir) |
|---|---|---|
| Base image | `autoware:base-cuda-devel-humble-2.1.0` (CUDA 12.8) | same tag; its manifest is multi-arch |
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
sudo dpkg -i autoware-localrepo-2-1-0_*ubuntu2204sbsa_all.deb
sudo /usr/share/autoware/2.1.0/setup-prerequisites.sh   # ROS 2, CUDA 12.8 libs, cuDNN, TensorRT 10.3, SpConv (arm64-sbsa)
sudo apt update
sudo apt install autoware-full-2-1-0
sudo /usr/share/autoware/2.1.0/activate-dds-config.sh
autoware-download-models-2-1-0     # as your own user, no sudo: ML models into ~/autoware_data
```

The ML models are not in the localrepo. The last line fetches them into
`~/autoware_data`, Autoware's default `data_path`, where TensorRT can also
write its engines; see "ML models (2.1.0+)" in the top-level `CLAUDE.md`.

The prerequisites script refuses to run on a Jetson.

## Configuration

### Package Naming

Packages are built with `-2-1-0` suffix to allow multiple Autoware versions to coexist:
- Example: `ros-humble-autoware-core-2-1-0` instead of `ros-humble-autoware-core`

This is configured in `config.yaml`:
```yaml
build:
  package_suffix: "2-1-0"
```

### Install Prefix

Packages install to `/opt/autoware/2.1.0` instead of the default `/opt/ros/humble`.

## Builder fixes for the 2.1.0 base image

The 2.1.0 builders start from upstream's release image instead of 1.x's
`autoware-base:cuda-latest`, and it differs in three ways that break
colcon2deb. The Dockerfile undoes each, as `../amd64/` does:

| Base image behaviour | Symptom | Fix |
|---|---|---|
| `ENTRYPOINT /docker-entrypoint.sh` ends with `exec gosu aw` | colcon2deb's entry runs unprivileged: `useradd: group '<gid>' does not exist` | `ENTRYPOINT []` |
| Python is `/opt/autoware-venv` via `ENV PATH`, which `su` drops | phase 7: `No module named 'rosdeb_bloom'` | `/colcon2deb-setup.sh` puts the venv back on PATH |
| (sets `RMW_IMPLEMENTATION`; set again so the build does not depend on it) | without it, `autoware_lidar_marker_localizer` fails in tinyxml2_vendor (seen on jp62) | `ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` |

## Patches (debian-overrides)

`debian-overrides/` holds 25 targeted patches, the 1.9.0 deltas ported to
2.1.0's bloom output by `scripts/port-overrides.py`, whose header lists them:

| Delta | Packages |
|---|---|
| LTO off in `debian/rules` (CUDA fatbin: `symbol 'fatbinData' is already defined`) | 16 CUDA packages (1.9.0's 17 less `trt_batched_nms`, gone in 2.1.0) |
| agnocast pinned to the system glog | `agnocastlib`, `agnocast_components`, `agnocast_e2e_test`, `agnocast_sample_application` |
| `Depends: autoware-acados-2-1-0` (they link libacados) | `autoware_path_optimizer`, `autoware_trajectory_modifier` |
| `Replaces:` | `autoware_mission_planner_universe`, `autoware_overlay_rviz_plugin` |
| core_planning depends on mission-planner-universe | `autoware_core_planning` |

To regenerate them, run `just ros` once with an empty `debian-overrides/`, then
`scripts/port-overrides.py 2.1.0/arm64`. bloom's output is the same for every
architecture of a version, so a harvest from one build fits the others.

## Building

```bash
# Build all packages
just ros

# Or manually
colcon2deb --workspace source --config config.yaml
```
