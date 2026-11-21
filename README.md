# Autoware Local Repository

Autoware as Debian packages. Each release is one package, the localrepo, that
carries every Autoware package of one version as a local APT repository, so
`apt install` works without any Autoware server. Versions install side by
side.

## Download

Pick a version, then the localrepo deb for your machine from its release.
2.1.0 is the newest; it is for ROS 2 Humble.

| Version | Release | Universe | Offline ML models |
|---|---|---|---|
| 2.1.0 | [2.1.0-1](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/2.1.0-1) | 0.53.2 | [data-2.1.0-1](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/data-2.1.0-1) |
| 1.9.0 | [1.9.0-2](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/1.9.0-2) | 0.52.0 | [data-1.9.0-1](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/data-1.9.0-1) |
| 1.7.1 | [1.7.1-2](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/1.7.1-2) | 0.50.0 | [data-1.7.1-1](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/data-1.7.1-1) |
| 1.5.0 | [1.5.0-humble-5](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/1.5.0-humble-5) | 0.48.0 | [data-1.5.0-1](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/data-1.5.0-1) |

Every release has a localrepo deb for each platform:

| Suffix | Platform |
|---|---|
| `ubuntu2204` | Ubuntu 22.04, x86_64 |
| `ubuntu2204sbsa` | Ubuntu 22.04, arm64 server (SBSA: Grace, Ampere Altra) |
| `jetpack62` | JetPack 6.2, Jetson Orin |
| `ubuntu2204cpu` | Ubuntu 22.04, x86_64, no NVIDIA GPU needed |
| `ubuntu2204arm64cpu` | Ubuntu 22.04, any arm64 machine, no NVIDIA GPU needed |

The two `cpu` builds were added to the 1.x releases on 2026-11-14 and are part
of 2.1.0 from its first release; see
[Machines without an NVIDIA GPU](#machines-without-an-nvidia-gpu).

The "Offline ML models" releases are only for machines that cannot download
the models; you do not need them otherwise. Each release's notes also say how
to upgrade from its previous revision.

## Contents

- About 460 to 500 Autoware packages for ROS 2 Humble, depending on the version
- `autoware-download-models-<version>`, which fetches the ML models
- CycloneDDS configuration
- Sample maps for planning simulation
- RViz theme and icons

## Install Autoware

The commands use 2.1.0 on x86_64; substitute your version (`2.1.0` in paths,
`2-1-0` in package names) and platform suffix.

```bash
# 1. Install the localrepo package
sudo dpkg -i autoware-localrepo-2-1-0_2.1.0-1ubuntu2204_all.deb

# 2. Install prerequisites (ROS 2 Humble, optionally CUDA, TensorRT, SpConv)
sudo /usr/share/autoware/2.1.0/setup-prerequisites.sh

# 3. Install Autoware from the localrepo
sudo apt update
sudo apt install autoware-full-2-1-0

# 4. Apply the DDS network settings (sysctl and loopback multicast)
sudo /usr/share/autoware/2.1.0/activate-dds-config.sh

# 5. Source the environment
source /opt/autoware/2.1.0/setup.bash          # workspace (ament, ROS)
source /opt/autoware/2.1.0/autoware-env.bash   # DDS, CycloneDDS, Qt
```

## Install the ML models

The localrepo does not carry the ML models (it did up to 1.5.0-2 and
1.7.1-1). They go into Autoware's default `data_path`, `~/autoware_data`
up to 1.7.1 and `~/autoware_data/ml_models` from 1.9.0, owned by the user who launches Autoware: on first launch TensorRT compiles
each model into an `.engine` file next to it, so that user must be able to
write there. Set them up as that user, **not with sudo**; the tool refuses to
run as root unless given `--dir`.

### Download (recommended)

```bash
autoware-download-models-2-1-0
```

It fetches every model from its upstream URL and checks each file's sha256.
Re-running resumes partial downloads and skips files that already verify.
`--list` shows the models; `--only lidar_centerpoint,tensorrt_yolox` or
`--group perception3d|planning|vision` fetches a subset.

### Models from an earlier 1.9.0 or 2.1.0 release

Up to 1.9.0-2, 2.1.0-1 and 2.1.0-jazzy-1 the downloader put the models in
`~/autoware_data`, but the launch files of 1.9.0 and later read
`~/autoware_data/ml_models`, so a launch without `data_path:=` found none.
From 1.9.0-humble-3, 2.1.0-humble-2 and 2.1.0-jazzy-2 it writes to
`~/autoware_data/ml_models`, and when it finds this version's models in the
old place it stops and prints the command that moves them (keeping the
TensorRT engines). Alternatively keep them there and launch with
`data_path:=$HOME/autoware_data`.

### Offline, from the autoware-data debs

For a machine that cannot reach the model servers (`awf.ml.dev.web.auto`,
Hugging Face, S3). Download the debs from the version's "Offline ML models"
release above, then:

```bash
sudo dpkg -i autoware-data-*2-1-0_2.1.0-1_all.deb       # into /opt/autoware/2.1.0/data
autoware-download-models-2-1-0 --link-from /opt/autoware/2.1.0/data
autoware-download-models-2-1-0 --verify
```

The default directory then holds your own directories with symlinks into the
root-owned `/opt/autoware/2.1.0/data`, so TensorRT can still write its
engines there.

## Network Configuration

Step 4 above applies the DDS settings. To apply them again later:
```bash
sudo /usr/share/autoware/2.1.0/activate-dds-config.sh
```

## Testing

Run planning simulation with the bundled sample map:
```bash
ros2 launch autoware_launch planning_simulator.launch.xml \
  map_path:=/opt/autoware/2.1.0/share/autoware_maps/sample-map-planning \
  vehicle_model:=sample_vehicle \
  sensor_model:=sample_sensor_kit
```

In 1.5.0 and 1.7.1 the sample maps are their own package, not part of
`autoware-full`: `sudo apt install autoware-maps-1-7-1` first.

See [Planning Simulation Demo](https://autowarefoundation.github.io/autoware-documentation/main/demos/planning-sim/lane-driving/) for usage instructions.

## Supported NVIDIA GPUs

Turing or newer. Nothing is built for Volta or Pascal (V100, GTX 10xx), and
TensorRT 10 does not support them.

| GPU | amd64 1.5.0 | amd64 1.7.1 to 2.1.0 | arm64 server | Jetson (jp62) |
|---|---|---|---|---|
| Turing: RTX 20, T4, T4G | yes | yes | yes | |
| A100, A30 | yes | yes | yes | |
| RTX 30, A10, A40 | yes | yes | yes | |
| RTX 40, L4, L40 | yes | yes | yes | |
| H100, H200, GH200 | yes | yes | yes | |
| B200, GB200 | no | yes | no | |
| RTX 50, RTX PRO 6000 Blackwell | no | yes | | |
| Orin | | | | yes |

- **1.5.0 on Blackwell:** 1.5.0 is built with CUDA 12.4, which cannot target
  Blackwell GPUs. Most kernels would still run, compiled by the driver on first
  launch, but the occupancy grid map library carries only code for the exact
  GPUs it was built for, so it fails on any Blackwell GPU. Use 1.9.0 or 2.1.0.
- **arm64 servers:** these use TensorRT 10.3, the newest version NVIDIA
  publishes for Ubuntu 22.04 arm64 servers, and it cannot build engines for
  Blackwell (GB200, DGX Spark).
- **Drivers:** a driver that supports CUDA 12.8 (R570 or newer) for amd64, and
  CUDA 12.5 for arm64 servers.

## Machines without an NVIDIA GPU

The `ubuntu2204cpu` (x86_64) and `ubuntu2204arm64cpu` (arm64) localrepos are
built without CUDA, cuDNN or TensorRT, and nothing in them depends on an NVIDIA
library. Install them as above, but give the prerequisites script `--ros` alone:

```bash
sudo /usr/share/autoware/2.1.0/setup-prerequisites.sh --non-interactive --ros
```

Autoware's GPU packages build their CPU half or nothing without CUDA, and the
GPU-only ones are installed as empty packages so the rest still resolves. What
works and what does not:

- **Works:** planning, control, localization by NDT, the planning simulator,
  and LiDAR object detection by Euclidean clustering.
- **Missing:** every neural network (CenterPoint, TransFusion, BEVFusion,
  YOLOX, the traffic light classifiers), the CUDA pointcloud preprocessor and
  ground segmentation, and the pointcloud-based occupancy grid map.
- **Perception must be told:** launch with `lidar_detection_model:=clustering`
  and `occupancy_grid_map_method:=laserscan_based` (arguments of
  `autoware.launch.xml`). The defaults name GPU nodes that are not there.
  This perception setup is not yet tested; the planning simulator is.

The ML models are not needed. A CPU build and a CUDA build of the same version
have the same package names, so a machine runs one of them: to switch, remove
the installed one with `uninstall-autoware.sh --purge` first.

## Several Autoware versions

Versions install side by side: every package name carries the version
(`autoware-full-1-5-0`, `autoware-full-1-9-0`), and each version lives in
`/opt/autoware/<version>`. Install each version's localrepo package, then
`apt install autoware-full-<version>`, and source the setup.bash of the
version you want. Keep each version's models in their own directory:
`autoware-download-models-2-1-0 --dir ~/autoware_data-2.1.0`, then launch with
`data_path:=$HOME/autoware_data-2.1.0`.

Releases before 1.5.0-3 and 1.7.1-2 all ship `/usr/bin/apply-autoware-theme`
and cannot be installed beside another version. Upgrade them first; the
1.5.0-3 and 1.7.1-2 release notes give the steps.

## Uninstallation

```bash
# Remove Autoware 2.1.0, keeping its localrepo for a quick reinstall
sudo /usr/share/autoware/2.1.0/uninstall-autoware.sh

# Remove 2.1.0 completely: config files, localrepo, /opt/autoware/2.1.0
sudo /usr/share/autoware/2.1.0/uninstall-autoware.sh --purge
```

Each version's script removes only that version. With several installed, run
each one's own script, e.g. `/usr/share/autoware/1.5.0/uninstall-autoware.sh`.

The script lists what it will remove and asks first; `-y` skips the questions.
It also offers to remove the dependencies Autoware pulled in that nothing else
needs any more, after listing them. Other installed Autoware versions, and
packages you installed yourself, keep what they depend on. Prerequisites
(ROS 2, CUDA, TensorRT) stay. So do the models in each user's
`~/autoware_data`: the script lists them, and you delete them with `rm -rf`.

## Building

Each `<version>/<platform>/` directory builds its own localrepo with
[colcon2deb](https://github.com/NEWSLabNTU/colcon2deb); see
[BUILDING.md](BUILDING.md). The `<version>/<arch>-cpu/` directories are
generated from their CUDA siblings by `scripts/derive-cpu.py` and are never
edited by hand. Releases are built on local machines and attached
with `scripts/publish-release.sh`, which keeps the offline model debs in their
own `data-<version>` releases.
