# Autoware Local Repository

Pre-built Debian packages for [Autoware](https://autowarefoundation.github.io/autoware-documentation/main/), the open-source autonomous driving software stack.

## Autoware 1.5.0

### Supported Platforms

| Platform | Architecture | Base OS |
|----------|--------------|---------|
| AMD64 | x86_64 | Ubuntu 22.04 |
| JetPack 6.2 | arm64 | L4T r36.4 (Jetson Orin) |

### Download

Download from [Releases](https://github.com/NEWSLabNTU/autoware-localrepo/releases):
- `autoware-localrepo_1.5.0-1_amd64.deb` - For Ubuntu 22.04 x86_64
- `autoware-localrepo_1.5.0-1_jp62.deb` - For JetPack 6.2 (Jetson Orin)

### Installation

```bash
# 1. Install the localrepo package
sudo dpkg -i autoware-localrepo_1.5.0-1_<platform>.deb

# 2. Install prerequisites (ROS 2 Humble, optionally CUDA/TensorRT/SpConv)
sudo /usr/share/autoware/setup-prerequisites.sh

# 3. Install Autoware
sudo apt update
sudo apt install autoware-full

# 4. Source the environment
source /opt/autoware/1.5.0/setup.bash
```

### Network Configuration

Apply DDS settings for optimal performance (required for point clouds):
```bash
sudo /usr/share/autoware/activate-dds-config.sh
```

### Testing

Run planning simulation with the bundled sample map:
```bash
ros2 launch autoware_launch planning_simulator.launch.xml \
  map_path:=/opt/autoware/1.5.0/share/autoware_maps/sample-map-planning \
  vehicle_model:=sample_vehicle \
  sensor_model:=sample_sensor_kit
```

See [Planning Simulation Demo](https://autowarefoundation.github.io/autoware-documentation/main/demos/planning-sim/lane-driving/) for usage instructions.

### Uninstallation

```bash
sudo /usr/share/autoware/uninstall-autoware.sh
sudo dpkg -r autoware-localrepo
```

## Package Contents

The localrepo bundles approximately 460 packages:

| Package | Description |
|---------|-------------|
| `autoware-full` | Meta-package for complete installation |
| `autoware-ros-packages` | 450+ ROS 2 Humble packages for Autoware |
| `autoware-config` | CycloneDDS configuration, setup scripts |
| `autoware-data` | ML models (ONNX) for perception |
| `autoware-theme` | RViz icons and Qt theme |
| `autoware-maps` | Sample maps for planning simulation |
| `autoware-rosbag-sample` | Sample rosbag for replay demo |

### Helper Scripts

Installed to `/usr/share/autoware/`:

| Script | Purpose |
|--------|---------|
| `setup-prerequisites.sh` | Installs ROS 2 Humble, CUDA, TensorRT, SpConv |
| `activate-dds-config.sh` | Applies sysctl settings and enables multicast |
| `uninstall-autoware.sh` | Removes all Autoware packages |

## Project Structure

```
autoware-localrepo/
├── 1.5.0/
│   ├── amd64/                # Build for Ubuntu 22.04 x86_64
│   │   ├── packages/         # Meta-packages (autoware-config, etc.)
│   │   ├── debian-overrides/ # Patches for ROS packages
│   │   ├── build/            # colcon2deb output
│   │   └── justfile
│   └── jp62/                 # Build for JetPack 6.2 arm64
│       └── ...
└── justfile
```

## Building from Source

See [BUILDING.md](BUILDING.md) for instructions on building the localrepo packages manually.

## License

Apache License 2.0
