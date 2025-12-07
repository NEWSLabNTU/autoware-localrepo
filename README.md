# Autoware Local Repository Builder

This project builds Debian packages for multiple Autoware versions and
creates a local APT repository for easy installation on Debian/Ubuntu systems.

## Prerequisites

- **Ubuntu 22.04** (Jammy) operating system
- **Docker** for building ROS packages via colcon2deb
- **debhelper** package (`sudo apt install debhelper devscripts`)
- **just** command runner (`cargo install just` or from package manager)

## Repository Structure

```
autoware-localrepo/
├── common/                    # Shared packages
│   └── autoware-localrepo/    # APT repo configuration package
├── 1.5.0/                     # Autoware 1.5.0
│   ├── amd64/                 # colcon2deb build config for amd64
│   │   ├── config.yaml
│   │   ├── Dockerfile
│   │   ├── justfile
│   │   ├── debian-overrides/
│   │   ├── source/            # Clone Autoware here (git-ignored)
│   │   └── build/             # Build output (git-ignored)
│   ├── arm64/                 # colcon2deb build config for arm64
│   ├── packages/              # Debhelper packages
│   │   ├── autoware-config/   # System configuration (arch: all)
│   │   ├── autoware-theme/    # RViz theme/icons (arch: all)
│   │   ├── autoware-runtime/  # Meta-package for ROS debs (arch: any)
│   │   └── autoware-full/     # Complete install meta-package
│   ├── output/                # Consolidated debs (git-ignored)
│   └── justfile
├── 2025.02/                   # Autoware 2025.02 (same structure)
├── repo/                      # Final APT repository (git-ignored)
└── justfile                   # Top-level build automation
```

## Quick Start

### 1. Prepare Autoware Source

```bash
cd 1.5.0/amd64

# Clone Autoware
git clone --branch 1.5.0-ws https://github.com/NEWSLabNTU/autoware.git source
cd source && vcs import src < autoware.repos && cd ..
```

### 2. Build ROS Packages

```bash
# Build using colcon2deb (runs in Docker)
just build
```

### 3. Build Meta-Packages

```bash
cd ..  # Back to 1.5.0/
just build-packages
```

### 4. Consolidate and Create Repository

```bash
just consolidate

# From top-level directory
cd ..
just create-repo
```

## Package Types

| Package              | Architecture | Description                                |
|----------------------|--------------|--------------------------------------------|
| `autoware-config`    | all          | CycloneDDS config, environment setup       |
| `autoware-theme`     | all          | RViz icons and Qt theme                    |
| `autoware-runtime`   | any          | Meta-package depending on all ROS packages |
| `autoware-full`      | any          | Complete Autoware installation             |
| `autoware-localrepo` | all          | APT repository configuration               |

## Installation on Target System

```bash
# Install the repository configuration
sudo dpkg -i autoware-localrepo_*.deb

# Copy repository files to /opt/autoware/repo
sudo mkdir -p /opt/autoware/repo
sudo cp -r repo/* /opt/autoware/repo/

# Update package list
sudo apt update

# Install Autoware
sudo apt install autoware-full
```

## License

Apache License 2.0
