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
`debian-overrides/`, then the script. See `../../2.1.0/amd64/README.md` for
what each delta is.

## Building

```bash
just ros        # ROS packages (colcon2deb)
just all        # + meta-packages + bundled localrepo
just test       # install test in nvidia/cuda:13.0.0-runtime-ubuntu24.04
```

The GPU-free sibling `../amd64-cpu/` is generated from this directory by
`scripts/derive-cpu.py 2.1.0-jazzy/amd64`; never edit it by hand.
