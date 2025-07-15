# autoware-data

This package contains ML models and data files required by Autoware for autonomous driving functionality.

## Overview

The autoware-data package downloads and installs various machine learning models and configuration files used by Autoware components, including:

- Object detection models (YOLOX, CenterPoint, TransFusion)
- Traffic light detection and classification models
- Semantic segmentation models
- LiDAR processing models
- Various configuration and calibration files

All files are installed to `/opt/autoware/data/` directory.

## Build Procedure

To build the package:

```bash
make build
```

This will:
1. Run `genpkg.py --update` to update the PKGBUILD file from tasks.yaml
2. Execute `makedeb -d` to build the Debian package

To clean build artifacts:

```bash
make clean
```

## Getting tasks.yaml

The `tasks.yaml` file defines which models and data files to download. It is copied from the Autoware repository:

- Source: `$autoware_repo/ansible/roles/artifacts/tasks/main.yaml`
- Release: Autoware 2025.02

To update tasks.yaml with a newer version:
1. Clone or checkout the desired Autoware release
2. Copy the file from `ansible/roles/artifacts/tasks/main.yaml` to this directory as `tasks.yaml`
3. Run `make build` to regenerate the package with the updated models

## Development

The build process works as follows:

1. `tasks.yaml` contains Ansible tasks that specify URLs and installation paths for each file
2. `genpkg.py` parses tasks.yaml and generates the appropriate PKGBUILD content
3. `makedeb` uses the PKGBUILD to download files and create the Debian package

The script automatically handles:
- Extracting tar.gz archives
- Installing individual files to their correct locations
- Showing a diff of changes before updating (run `./genpkg.py` without arguments)

## Using genpkg.py

```bash
# Show diff of changes
./genpkg.py

# Update PKGBUILD file
./genpkg.py --update

# Use custom files
./genpkg.py -t custom_tasks.yaml -p custom.PKGBUILD

# Show help
./genpkg.py --help
```