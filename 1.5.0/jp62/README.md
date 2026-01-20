# Autoware 1.5.0 JetPack 6.2 (ARM64) Build

This directory contains the colcon2deb configuration for building Autoware 1.5.0 ROS packages on NVIDIA Jetson with JetPack 6.2.

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

### Cross-Compilation (Multi-Arch Setup)

Building ARM64 Docker images on an x86_64 host requires QEMU user-mode emulation.

**Prerequisites** (one-time setup on x86 host):
```bash
# Install QEMU user-mode emulation
sudo apt install qemu-user-static

# Register QEMU binary formats with credential support
# The --credential flag sets binfmt flags to OCF, allowing setuid binaries (like sudo) to work
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
```

**Verify registration:**
```bash
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
# Should show: flags: OCF
```

**Note:** The registration persists across reboots but may need to be re-run after kernel updates or Docker daemon restarts. If builds suddenly fail with sudo errors, re-run the registration command.

**config.yaml setting**:
```yaml
docker:
  platform: linux/arm64
```

**Performance:** ARM64 builds under QEMU are significantly slower than native builds (expect 10-20x slower). A full Autoware build can take several hours.

**Memory:** QEMU emulation uses significantly more memory than native execution. To avoid segmentation faults during linking, use low parallel job counts:
```yaml
build:
  parallel_jobs: 2  # Use 2 or less for QEMU, 8+ for native ARM64
```

**ASLR Workaround:** On Linux kernels ≥6.8.0-50, QEMU user-mode emulation has a known incompatibility with ASLR (Address Space Layout Randomization) that causes random segmentation faults during compilation:
```
c++: internal compiler error: Segmentation fault signal terminated program cc1plus
```

**Solution**: Temporarily disable ASLR during the build:
```bash
# Disable ASLR before build
sudo sysctl kernel.randomize_va_space=0

# Run the build
just ros

# Re-enable ASLR after build completes
sudo sysctl kernel.randomize_va_space=2
```

**Security note:** Disabling ASLR reduces system security. Only disable it temporarily during builds and re-enable immediately after. For security-critical environments, consider building on native ARM64 hardware instead.

## Dockerfile Workarounds

### OpenCV Version Conflict (opencv-preferences)

NVIDIA's L4T base image includes OpenCV 4.8.0 installed directly (not via APT). This conflicts with Ubuntu's OpenCV 4.5.4 that ROS packages and cv_bridge expect:

```
The imported target "opencv_core" references the file
"/usr/lib/libopencv_core.so.4.8.0" but this file does not exist.
```

**Solution**: The Dockerfile removes all L4T OpenCV files and uses `opencv-preferences` to pin APT to Ubuntu's packages:

```
# opencv-preferences
Package: libopencv*
Pin: release o=Ubuntu
Pin-Priority: 1001

Package: opencv-data
Pin: release o=Ubuntu
Pin-Priority: 1001

Package: python3-opencv
Pin: release o=Ubuntu
Pin-Priority: 1001
```

### Old CMake in L4T Base Image

L4T ships CMake 3.14.4 in `/usr/local/bin` which is too old for Autoware (requires 3.16+). The Dockerfile removes it and installs Ubuntu's CMake 3.22.1.

### CUDA Architecture Detection (QEMU)

Under QEMU emulation, `CUDA_ARCHITECTURES native` fails because there's no GPU. The Dockerfile sets:
```dockerfile
ENV CUDAARCHS=87  # Orin for JetPack 6.x
```

### Setuid/Sudo Issues (QEMU)

QEMU user-mode emulation requires the `--credential yes` flag to properly handle setuid binaries like `sudo`. Without it, you'll see:
```
sudo: effective uid is not 0, is /usr/bin/sudo on a file system with the 'nosuid' option set or an NFS file system without root privileges?
```

**Solution**: Re-register QEMU with credential support (see Prerequisites above):
```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
```

**Fallback**: If sudo still fails, skip rosdep install since dependencies are pre-installed in the Dockerfile:
```bash
colcon2deb --workspace source --config config.yaml --skip-rosdep-install
```

### CUDNN Detection (cuda_init.cmake)

The ROS `cudnn_cmake_module` requires `CUDA_FOUND` to be set before it runs. The `cuda_init.cmake` file ensures `find_package(CUDA)` runs early via `CMAKE_PROJECT_INCLUDE`.

**Important**: Under QEMU emulation, nvcc may produce unexpected output that causes CMake's `FindCUDA.cmake` to fail with REGEX errors. The `cuda_init.cmake` file validates nvcc output before calling `find_package(CUDA)`:

```cmake
# cuda_init.cmake (simplified)
if(NOT CUDA_FOUND)
  find_program(_CUDA_NVCC_EXECUTABLE nvcc ...)
  if(_CUDA_NVCC_EXECUTABLE)
    execute_process(COMMAND "${_CUDA_NVCC_EXECUTABLE}" --version ...)
    # Only call find_package(CUDA) if nvcc output matches expected format
    if(_nvcc_result EQUAL 0 AND _nvcc_version_output MATCHES "release [0-9]+\\.[0-9]+")
      find_package(CUDA QUIET)
    endif()
  endif()
endif()
```

This prevents the following error on non-CUDA packages:
```
CMake Error at /usr/share/cmake-3.22/Modules/FindCUDA.cmake:929 (string):
  string sub-command REGEX, mode REPLACE needs at least 6 arguments
```

### spconv/cumm Libraries

Required by `autoware_tensorrt_plugins` for BEVFusion. Pre-built packages installed from autowarefoundation/spconv_cpp releases.

## Patches

### Replaces for Conflicting Files

Some packages have been renamed or merged but still install files to the same paths. This causes dpkg conflicts during installation. The fix is to add `Replaces:` to the new package's `debian/control`.

**Fix**: Add `Replaces:` field after the `Depends:` line in `debian/control`:

| Package | Replaces | Reason |
|---------|----------|--------|
| `autoware_mission_planner_universe` | `ros-humble-autoware-mission-planner-1-5-0` | Supersedes autoware_mission_planner |
| `autoware_overlay_rviz_plugin` | `ros-humble-autoware-mission-details-overlay-rviz-plugin-1-5-0` | Absorbed mission_details_overlay functionality |

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

**Affected packages (24 total)**:
- autoware_bevfusion
- autoware_calibration_status_classifier
- autoware_camera_streampetr
- autoware_cuda_pointcloud_preprocessor
- autoware_cuda_utils
- autoware_diffusion_planner
- autoware_image_projection_based_fusion
- autoware_lidar_centerpoint
- autoware_lidar_frnet
- autoware_lidar_transfusion
- autoware_probabilistic_occupancy_grid_map
- autoware_ptv3
- autoware_shape_estimation
- autoware_simpl_prediction
- autoware_tensorrt_bevformer
- autoware_tensorrt_classifier
- autoware_tensorrt_common
- autoware_tensorrt_plugins
- autoware_tensorrt_yolox
- autoware_traffic_light_classifier
- autoware_traffic_light_fine_detector
- bevdet_vendor
- cuda_blackboard
- trt_batched_nms

## Regenerating debian-overrides

If you need to regenerate the debian-overrides directory:

```bash
# Delete existing overrides
rm -rf debian-overrides/*

# Regenerate with colcon2deb
colcon2deb --workspace source --config config.yaml --generate-debian-only

# Re-apply patches:
# 1. CUDA LTO fixes - add to debian/rules (see LTO section above - 24 packages)
# 2. Replaces fixes - add to debian/control (see Replaces section above)
```

## Building

```bash
# Build all packages (very slow under QEMU emulation)
just ros

# Or manually
colcon2deb --workspace source --config config.yaml

# Monitor build progress
tail -f build/log/latest/*colcon_build.log
```

## Differences from AMD64

The jp62 build has 24 CUDA packages requiring LTO fixes vs 17 for amd64. Additional packages on Jetson:
- autoware_calibration_status_classifier
- autoware_diffusion_planner
- autoware_image_projection_based_fusion
- autoware_shape_estimation
- autoware_simpl_prediction
- autoware_traffic_light_classifier
- autoware_traffic_light_fine_detector
- cuda_blackboard
