# Autoware 2.1.0 Jazzy arm64 Server Build

colcon2deb configuration for building Autoware 2.1.0 on ROS 2 Jazzy
(Ubuntu 24.04, noble) for **generic arm64 servers** (SBSA): an aarch64 host
with a discrete NVIDIA GPU, such as Grace Hopper (GH200), an Ampere Altra with
an A100/H100, or any other Ubuntu 24.04 arm64 machine running NVIDIA's SBSA
CUDA stack. It is not for Jetson.

It is `../amd64/` (Jazzy) with the arm64 changes of `../../2.1.0/arm64/`
(Humble): the builder fetches the `linux-arm64` tera renderer for acados,
`packages/autoware-acados-2-1-0` is `Architecture: any`, `config.yaml` sets
`platform: linux/arm64`, SpConv comes as the `arm64` debs, and the localrepo
version suffix is `ubuntu2404sbsa` so its file name does not collide with the
amd64 one in a release. The source submodule is the same workspace
(NEWSLabNTU/autoware, branch `2.1.0-ws`).

Unlike Humble arm64, TensorRT is the amd64 pin (10.13.3.9-1+cuda13.0):
NVIDIA's `ubuntu2404/sbsa` repository carries it, where `ubuntu2204/sbsa`
stops at 10.3. The extra sm_80/90/100 SASS and compute_75 PTX from
`NVCC_APPEND_FLAGS` are the same as on every 2.1.0 GPU build.

### Installing

```bash
sudo dpkg -i autoware-localrepo-2-1-0_*ubuntu2404sbsa_all.deb
sudo /usr/share/autoware/2.1.0/setup-prerequisites.sh   # ROS 2 Jazzy, CUDA 13.0 libs, cuDNN, TensorRT 10.13, SpConv (arm64)
sudo apt update
sudo apt install autoware-full-2-1-0
sudo /usr/share/autoware/2.1.0/activate-dds-config.sh
autoware-download-models-2-1-0     # as your own user, no sudo: ML models into ~/autoware_data
```

The prerequisites script refuses to run on a Jetson.

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
| Jazzy arm64 server | `autoware-localrepo-2-1-0_2.1.0-1ubuntu2404sbsa_all.deb` |
| Jazzy arm64 GPU-free | `autoware-localrepo-2-1-0_2.1.0-1ubuntu2404arm64cpu_all.deb` |

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
2.1.0-jazzy/arm64`, which takes the distro from `config.yaml` and writes
`ros-jazzy-*` names. bloom's output is the same for every architecture of a
version, so a harvest from one build fits the others. See
`../../2.1.0/amd64/README.md` for what each delta is.

## Building

```bash
just ros        # ROS packages (colcon2deb)
just all        # + meta-packages + bundled localrepo
just test       # install test in nvidia/cuda:13.0.0-runtime-ubuntu24.04
```

The GPU-free sibling `../arm64-cpu/` is generated from this directory by
`scripts/derive-cpu.py 2.1.0-jazzy/arm64`; never edit it by hand.
