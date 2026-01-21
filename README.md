# Autoware Local Repository

Debian packages for Autoware 1.5.0, bundled as a local APT repository.

## Download

| File | Platform |
|------|----------|
| [autoware-localrepo-1-5-0_1.5.0-1ubuntu2204_all.deb](https://github.com/NEWSLabNTU/autoware-localrepo/releases/download/1.5.0-1/autoware-localrepo-1-5-0_1.5.0-1ubuntu2204_all.deb) | Ubuntu 22.04 x86_64 |
| [autoware-localrepo-1-5-0_1.5.0-1jetpack62_all.deb](https://github.com/NEWSLabNTU/autoware-localrepo/releases/download/1.5.0-1/autoware-localrepo-1-5-0_1.5.0-1jetpack62_all.deb) | JetPack 6.2 (Jetson Orin) |

## Contents

- 450+ ROS 2 Humble packages for Autoware
- ML models (ONNX) for perception
- CycloneDDS configuration
- Sample maps for planning simulation
- RViz theme and icons

## Installation

```bash
# 1. Install the localrepo package
sudo dpkg -i autoware-localrepo-1-5-0_1.5.0-1ubuntu2204_all.deb  # or 1jetpack62 for Jetson

# 2. Install prerequisites (ROS 2 Humble, optionally CUDA/TensorRT/SpConv)
sudo /usr/share/autoware/setup-prerequisites.sh

# 3. Install Autoware
sudo apt update
sudo apt install autoware-full-1-5-0

# 4. Source the environment
source /opt/autoware/1.5.0/setup.bash
```

## Network Configuration

Apply DDS settings for optimal performance:
```bash
sudo /usr/share/autoware/activate-dds-config.sh
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

## Uninstallation

```bash
sudo /usr/share/autoware/uninstall-autoware.sh
sudo dpkg -r autoware-localrepo-1-5-0
```
