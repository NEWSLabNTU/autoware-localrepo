# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the Autoware Local Repository Builder - a packaging system that creates local Debian/Ubuntu repositories containing Autoware packages. The project packages Autoware components, ML models, configurations, and themes into installable `.deb` packages for Ubuntu 22.04 systems.

## Common Development Tasks

### Building the Local Repository

```bash
# Prerequisites: makedeb and GNU Parallel must be installed
# Create packages directory with Autoware .deb files
mkdir packages
# Copy your Autoware .deb files into packages/

# Build the local repository
mkdir output
./build.sh ./packages ./output
```

### Building Individual Packages

```bash
# Build a specific package (run from package directory)
cd autoware-config && makedeb -d
cd autoware-data && makedeb -d
cd autoware-theme && makedeb -d
cd autoware-runtime && makedeb -d
cd autoware-full && makedeb -d
cd autoware-localrepo && makedeb -d
```

### Cleaning Build Artifacts

```bash
# Clean individual package builds
cd autoware-config && rm -f *.deb
cd autoware-data && rm -f *.deb
# ... repeat for other packages
```

## Architecture

The project consists of several interconnected packages:

1. **autoware-runtime**: Generated dynamically from input packages. Contains version-constrained dependencies for all Autoware ROS packages.

2. **autoware-config**: Configuration files including:
   - CycloneDDS configuration for ROS2 DDS communication
   - Environment setup scripts (setup.sh, setup.bash, setup.zsh)

3. **autoware-data**: ML models and data files:
   - ONNX models for object detection, traffic light classification, segmentation
   - Located in `/opt/autoware/data/` after installation

4. **autoware-theme**: UI customizations:
   - Qt5 themes for Autoware UI
   - RViz icons and configurations

5. **autoware-full**: Meta-package that depends on runtime and config packages

6. **autoware-localrepo**: The main package that:
   - Creates a local APT repository at `/opt/autoware-localrepo/`
   - Bundles all other packages
   - Configures APT sources for the local repository

### Build Process Flow

1. `build.sh` generates `autoware-runtime/packages.txt` from input .deb files
2. Builds all sub-packages in parallel using `makedeb`
3. Creates `packages.tar` containing all built packages
4. Builds `autoware-localrepo` which creates the APT repository structure

### Key Technologies

- **Packaging**: makedeb (Arch-style PKGBUILD for Debian/Ubuntu)
- **Repository**: dpkg-scanpackages for APT repository creation
- **Parallelization**: GNU Parallel for concurrent builds

## Important Notes

- Target platform is Ubuntu 22.04 (jammy)
- All packages use MIT license
- Version scheme: YEAR.MONTH-REVISION (e.g., 2025.2-1)
- The local repository is self-contained and doesn't require external repositories