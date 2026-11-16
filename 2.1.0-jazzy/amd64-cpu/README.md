# Autoware 2.1.0 Jazzy AMD64 Build

colcon2deb configuration for building Autoware 2.1.0 on ROS 2 Jazzy
(Ubuntu 24.04, noble) for x86_64. It is the Jazzy twin of `../../2.1.0/amd64/`
(Humble, Ubuntu 22.04); the source submodule is the same workspace
(NEWSLabNTU/autoware, branch `2.1.0-ws`).

## Configuration

### Package Naming

ROS packages are `ros-jazzy-<pkg>-2-1-0`, e.g. `ros-jazzy-autoware-core-2-1-0`.
The meta-packages keep the Humble names (`autoware-full-2-1-0`,
`autoware-config-2-1-0`, ...): Humble and Jazzy never share a machine (22.04
vs 24.04), and the localrepo revision tells them apart:

| Build | localrepo deb |
|---|---|
| Humble amd64 | `autoware-localrepo-2-1-0_2.1.0-1ubuntu2204_all.deb` |
| Jazzy amd64 | `autoware-localrepo-2-1-0_2.1.0-1ubuntu2404_all.deb` |
| Jazzy amd64 GPU-free | `autoware-localrepo-2-1-0_2.1.0-1ubuntu2404cpu_all.deb` |

`setup-prerequisites.sh` refuses anything but Ubuntu 24.04, so a Jazzy
localrepo cannot be set up on a Humble host by mistake.

### Install Prefix

Packages install to `/opt/autoware/2.1.0`, as on Humble.

## Builder (Dockerfile)

`FROM ghcr.io/autowarefoundation/autoware:base-cuda-devel-jazzy-2.1.0`, with
the same three fixes as the Humble builder (`ENTRYPOINT []`, the venv back on
PATH in `/colcon2deb-setup.sh`, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`). What
differs from Humble:

| | Humble | Jazzy |
|---|---|---|
| CUDA | 12.8 | 13.0 |
| TensorRT | 10.8.0.43 | 10.13.3.9 |
| cuDNN | `libcudnn9-cuda-12` | `libcudnn9-cuda-13` |
| spconv / cumm | `cu128` | `cu130-rev1` |
| Python | 3.10 | 3.12 |
| AutonomouStuff apt repo | yes | none (no noble suite; pacmod3_msgs is in the ROS repo) |

The versions are upstream's ansible defaults for Jazzy. The test image and
`setup-prerequisites.sh` install the matching runtime.

## Patches (debian-overrides)

Ported from the Humble 2.1.0 deltas by `scripts/port-overrides.py
2.1.0-jazzy/amd64`, which takes the distro from `config.yaml` and writes
`ros-jazzy-*` names. To regenerate them, run `just ros` once with an empty
`debian-overrides/`, then the script. It must harvest bloom's own output: on a
build that already applied the overrides its anchors are gone and it stops.
See `../../2.1.0/amd64/README.md` for what each delta is. Jazzy differs in two:

| Delta | Packages |
|---|---|
| `ROS_BASE_PATH ?= /opt/ros/jazzy` in `debian/rules`. colcon2deb before 0b1f427 wrote `/opt/ros/humble`, and `debian/rules` then found no ROS package (`No 'rosidl_typesupport_c' found`) | all 25 |
| gcc13: `-Wno-error=maybe-uninitialized`, for GCC 13's false positive in boost 1.83 `point_in_geometry.hpp`, fatal under the package's `-Werror` | `autoware_path_optimizer` |

The first comes from colcon2deb itself once it is new enough; the second is
`GCC13` in `scripts/port-overrides.py`, applied for Jazzy only. On arm64,
GCC 13 did not raise that warning; the override is kept there for parity.

## Meta-packages

The build host is Ubuntu 22.04, so `just meta localrepo` runs inside the noble
builder image rather than on the host: `autoware-acados-2-1-0` compiles acados
and has to link noble's libraries. Mount the host's `just`, since noble's
(1.21) cannot parse this justfile's `[confirm("...")]`:

```bash
docker run --rm --entrypoint "" -u root \
  -v "$PWD/../..:/repo" -v "$(which just):/usr/local/bin/just:ro" \
  -w /repo/2.1.0-jazzy/amd64 autoware-2.1.0-jazzy-amd64-builder bash -c \
  'apt-get update && apt-get install -y aria2 dpkg-dev debhelper parallel git cmake build-essential &&
   git config --global --add safe.directory "*" && just meta localrepo;
   chown -R '"$(id -u):$(id -g)"' packages build'
```

## Building

```bash
just ros        # ROS packages (colcon2deb)
just all        # + meta-packages + bundled localrepo
just test       # install test in nvidia/cuda:13.0.0-runtime-ubuntu24.04
```

The GPU-free sibling `../amd64-cpu/` is generated from this directory by
`scripts/derive-cpu.py 2.1.0-jazzy/amd64`; never edit it by hand.
