# Autoware 1.5.0 AMD64 Build

This directory contains the colcon2deb configuration for building Autoware 1.5.0 ROS packages on x86_64.

## Configuration

### Package Naming

Packages are built with `-1-5-0` suffix to allow multiple Autoware versions to coexist:
- Example: `ros-humble-autoware-core-1-5-0` instead of `ros-humble-autoware-core`

This is configured in `config.yaml`:
```yaml
build:
  package_suffix: "1-5-0"
```

### Install Prefix

Packages install to `/opt/autoware/1.5.0` instead of the default `/opt/ros/humble`.

## Patches

### LTO Disable for CUDA Packages

Ubuntu 22.04 enables LTO (Link Time Optimization) by default via `dpkg-buildflags`. This conflicts with CUDA's fatbin symbols during linking:

```
Error: symbol 'fatbinData' is already defined
lto-wrapper: fatal error: make returned 2 exit status
```

**Fix**: Add the following to the top of `debian/rules` (after the dh-make comment block):

```makefile
# Disable LTO - causes conflicts with CUDA fatbin symbols
export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto
```

**Affected packages (17 total)**:
- autoware_bevfusion
- autoware_camera_streampetr
- autoware_cuda_pointcloud_preprocessor
- autoware_cuda_utils
- autoware_lidar_centerpoint
- autoware_lidar_frnet
- autoware_lidar_transfusion
- autoware_probabilistic_occupancy_grid_map
- autoware_ptv3
- autoware_tensorrt_bevdet
- autoware_tensorrt_bevformer
- autoware_tensorrt_classifier
- autoware_tensorrt_common
- autoware_tensorrt_plugins
- autoware_tensorrt_yolox
- bevdet_vendor
- trt_batched_nms

## Regenerating debian-overrides

If you need to regenerate the debian-overrides directory:

```bash
# Delete existing overrides
rm -rf debian-overrides/*

# Regenerate with colcon2deb
colcon2deb --workspace source --config config.yaml --generate-debian-only

# Re-apply CUDA LTO fixes (see list above)
# Add to each package's debian/rules after the dh-make comment block:
# export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto
```

## Building

```bash
# Build all packages
just ros

# Or manually
colcon2deb --workspace source --config config.yaml
```
