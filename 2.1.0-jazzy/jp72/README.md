# Autoware 2.1.0 Jazzy JetPack 7.2 Build

colcon2deb configuration for building Autoware 2.1.0 on ROS 2 Jazzy for
**Jetson AGX Orin flashed with JetPack 7.2** (Jetson Linux r39.2, Ubuntu
24.04). JetPack 7.2 is the first JetPack 7 release that supports Orin; 7.0
and 7.1 (r38.x) were Thor only. An Orin on JetPack 6.2 (Ubuntu 22.04) uses
the Humble build in `../../2.1.0/jp62/` instead.

The source submodule is the same workspace as every 2.1.0 build
(NEWSLabNTU/autoware, branch `2.1.0-ws`).

## The NVIDIA stack

| | JetPack 6.2 (Humble, `../../2.1.0/jp62/`) | JetPack 7.2 (this dir) |
|---|---|---|
| L4T | r36.4 | r39.2 (pinned to 7.2.1) |
| Ubuntu | 22.04 | 24.04 |
| CUDA | 12.6 | **13.2.2** |
| cuDNN | 9.3 | 9.20.0.46-1 |
| TensorRT | 10.3 | **10.16.2.10-1+cuda13.2** |
| spconv / cumm | `cu128` `arm64-jetson` | `cu130-rev1` `arm64` |
| Localrepo version suffix | `jetpack62` | `jetpack72` |

**No NVIDIA base image.** nvcr.io's `l4t-jetpack`, `l4t-base`, `l4t-cuda` and
`l4t-tensorrt` stop at r36.4. The builder therefore starts from upstream
Autoware's GPU-free Jazzy image (`autoware:base-jazzy-2.1.0`, Ubuntu 24.04)
and adds NVIDIA's Jetson apt repository (`jetson/common` and `jetson/som`,
r39.2) and the CUDA, cuDNN and TensorRT packages from it, the way NVIDIA's own
l4t-jetpack Dockerfile does. The test image is plain `ubuntu:24.04`, with the
same packages installed by `setup-prerequisites.sh`.

**One aarch64 CUDA.** CUDA 13 ships a single aarch64 toolkit for SBSA and
Jetson, so spconv's cu130 release has no separate Jetson asset; its `arm64`
debs are the ones for Orin.

**Kernels.** `CUDAARCHS=87`: the builder has no GPU for "native" detection,
and an Orin needs no other architecture.

### Installing

```bash
sudo dpkg -i autoware-localrepo-2-1-0_*jetpack72_all.deb
sudo /usr/share/autoware/2.1.0/setup-prerequisites.sh   # ROS 2 Jazzy, CUDA 13.2, cuDNN 9.20, TensorRT 10.16 (pinned + held), SpConv
sudo apt update
sudo apt install autoware-full-2-1-0
sudo /usr/share/autoware/2.1.0/activate-dds-config.sh
autoware-download-models-2-1-0     # as your own user, no sudo: ML models into ~/autoware_data
```

The prerequisites script refuses a Jetson that is not on r39.2.

## Patches (debian-overrides)

The 25 overrides of `../amd64/` (ported by `scripts/port-overrides.py`),
unchanged: bloom's output does not differ between the architectures. CUDA
13.2 and TensorRT 10.16 needed no further override or fork patch; all 496
packages build against them as they are.

**OpenCV.** `jetson/common` r39.2 carries NVIDIA's `libopencv-dev` 4.8.0,
built without the contrib modules, and its version beats noble's 4.6.0. In the
builder that made `libopencv-contrib-dev` uninstallable and
`yabloc_image_processing` failed on a missing `opencv2/ximgproc`.
`opencv-preferences` pins every OpenCV package to Ubuntu's archive, as in
`../../2.1.0/jp62/`. The debs link Ubuntu's runtime libraries
(`libopencv_*.so.406`), which install beside NVIDIA's on a device.

## Building

```bash
just ros        # ROS packages (colcon2deb)
just all        # + meta-packages + bundled localrepo
just test       # install test in ubuntu:24.04 with the r39.2 repository
```

Build natively on an arm64 host; no GPU is needed.
