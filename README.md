# Autoware Local Repository

Debian packages for Autoware 1.5.0, bundled as a local APT repository.

## Download

| File | Platform |
|------|----------|
| [autoware-localrepo-1-5-0_1.5.0-1ubuntu2204_all.deb](https://github.com/NEWSLabNTU/autoware-localrepo/releases/download/1.5.0-1/autoware-localrepo-1-5-0_1.5.0-1ubuntu2204_all.deb) | Ubuntu 22.04 x86_64 |
| [autoware-localrepo-1-5-0_1.5.0-1jetpack62_all.deb](https://github.com/NEWSLabNTU/autoware-localrepo/releases/download/1.5.0-1/autoware-localrepo-1-5-0_1.5.0-1jetpack62_all.deb) | JetPack 6.2 (Jetson Orin) |

arm64 servers (SBSA, e.g. Grace or Ampere Altra with A100/H100) have their own
build with the suffix `ubuntu2204sbsa`, made from `<version>/arm64/`; see
that directory's README.md. It is not attached to a release yet.

## Contents

- 450+ ROS 2 Humble packages for Autoware
- A downloader for the ML models (ONNX); the models themselves are bundled only up to 1.5.0-2
- CycloneDDS configuration
- Sample maps for planning simulation
- RViz theme and icons

## Installation

```bash
# 1. Install the localrepo package
sudo dpkg -i autoware-localrepo-1-5-0_1.5.0-1ubuntu2204_all.deb  # or 1jetpack62 for Jetson

# 2. Install prerequisites (ROS 2 Humble, optionally CUDA/TensorRT/SpConv)
sudo /usr/share/autoware/1.5.0/setup-prerequisites.sh

# 3. Install Autoware
sudo apt update
sudo apt install autoware-full-1-5-0

# 4. Download the ML models (1.5.0-3 and later), as your own user, not sudo
autoware-download-models-1-5-0

# 5. Source the environment
source /opt/autoware/1.5.0/setup.bash
```

From 1.5.0-3 the localrepo does not carry the ML models. Step 4 downloads them
into `~/autoware_data`, which is Autoware's default `data_path`, and verifies
each file's checksum. It must run as the user who launches Autoware: TensorRT
compiles each model into an `.engine` file next to it on first launch, so the
directory has to be writable by that user. `--list` shows the models,
`--only lidar_centerpoint,...` fetches a subset, and `--help` covers offline
installs from the `autoware-data` deb.

## Network Configuration

Apply DDS settings for optimal performance:
```bash
sudo /usr/share/autoware/1.5.0/activate-dds-config.sh
```

## Testing

Run planning simulation with the bundled sample map:
```bash
ros2 launch autoware_launch planning_simulator.launch.xml \
  map_path:=/opt/autoware/1.5.0/share/autoware_maps/sample-map-planning \
  vehicle_model:=sample_vehicle \
  sensor_model:=sample_sensor_kit
```

See [Planning Simulation Demo](https://autowarefoundation.github.io/autoware-documentation/main/demos/planning-sim/lane-driving/) for usage instructions.

## Supported NVIDIA GPUs

Turing or newer. Nothing is built for Volta or Pascal (V100, GTX 10xx), and
TensorRT 10 does not support them.

| GPU | amd64 1.5.0 | amd64 1.9.0 | arm64 server | Jetson (jp62) |
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
  GPUs it was built for, so it fails on any Blackwell GPU. Use 1.9.0.
- **arm64 servers:** these use TensorRT 10.3, the newest version NVIDIA
  publishes for Ubuntu 22.04 arm64 servers, and it cannot build engines for
  Blackwell (GB200, DGX Spark).
- **Drivers:** a driver that supports CUDA 12.8 (R570 or newer) for amd64, and
  CUDA 12.5 for arm64 servers.

## Several Autoware versions

Versions install side by side: every package name carries the version
(`autoware-full-1-5-0`, `autoware-full-1-9-0`), and each version lives in
`/opt/autoware/<version>`. Install each version's localrepo package, then
`apt install autoware-full-<version>`, and source the setup.bash of the
version you want. Keep each version's models in their own directory:
`autoware-download-models-1-9-0 --dir ~/autoware_data-1.9.0`, then launch with
`data_path:=$HOME/autoware_data-1.9.0`.

Releases before 1.5.0-3 and 1.7.1-2 all ship `/usr/bin/apply-autoware-theme`
and cannot be installed beside another version. Upgrade them first.

## Uninstallation

```bash
# Remove Autoware 1.5.0, keeping its localrepo for a quick reinstall
sudo /usr/share/autoware/1.5.0/uninstall-autoware.sh

# Remove 1.5.0 completely: config files, localrepo, /opt/autoware/1.5.0
sudo /usr/share/autoware/1.5.0/uninstall-autoware.sh --purge

# Remove every Autoware version from this machine
sudo /usr/share/autoware/1.5.0/uninstall-autoware.sh --purge --all-versions
```

The script lists what it will remove and asks first; `-y` skips the questions.
It also offers to remove the dependencies Autoware pulled in that nothing else
needs any more, after listing them. Other installed Autoware versions, and
packages you installed yourself, keep what they depend on. Prerequisites
(ROS 2, CUDA, TensorRT) stay. So do the models in each user's
`~/autoware_data`: the script lists them, and you delete them with `rm -rf`.
