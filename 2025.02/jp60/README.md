# Autoware 2025.02 JetPack 6.0 (ARM64) Build

This directory contains the colcon2deb configuration for building Autoware 2025.02 ROS packages on NVIDIA Jetson with JetPack 6.0.

## Configuration

### Package Naming

Packages are built with a version suffix to allow multiple Autoware versions to coexist. Check `config.yaml` for the `package_suffix` setting.

### Install Prefix

Packages install to `/opt/autoware/2025.02` instead of the default `/opt/ros/humble`.

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

**ASLR Workaround (Kernel ≥6.8.0-50):** On newer kernels, QEMU has a known incompatibility with ASLR that causes random compiler segfaults (`cc1plus: internal compiler error: Segmentation fault`). Temporarily disable ASLR during builds:
```bash
sudo sysctl kernel.randomize_va_space=0   # Disable before build
just ros                                    # Run build
sudo sysctl kernel.randomize_va_space=2   # Re-enable after build
```

## Dockerfile Workarounds

### OpenCV Version Conflict (opencv-preferences)

NVIDIA's L4T base image includes OpenCV 4.8.0 installed directly (not via APT). This conflicts with Ubuntu's OpenCV 4.5.4 that ROS packages and cv_bridge expect.

**Solution**: The Dockerfile removes all L4T OpenCV files and uses `opencv-preferences` to pin APT to Ubuntu's packages.

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
sudo: effective uid is not 0, is /usr/bin/sudo on a file system with the 'nosuid' option set...
```

**Solution**: Re-register QEMU with credential support (see Prerequisites above).

### CUDNN Detection (cuda_init.cmake)

The ROS `cudnn_cmake_module` requires `CUDA_FOUND` to be set before it runs. The `cuda_init.cmake` file ensures `find_package(CUDA)` runs early.

## Patches

### LTO Disable for CUDA Packages

Ubuntu 22.04 enables LTO (Link Time Optimization) by default via `dpkg-buildflags`. This conflicts with CUDA's fatbin symbols during linking.

**Fix**: Add the following to the top of `debian/rules` (after the dh-make comment block) for CUDA packages:

```makefile
# Disable LTO - causes conflicts with CUDA fatbin symbols
export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto
```

See `debian-overrides-fixes.md` or the version-specific README for the list of affected CUDA packages.

## Building

```bash
# Build all packages (very slow under QEMU emulation)
just ros

# Or manually
colcon2deb --workspace source --config config.yaml

# Monitor build progress
tail -f build/logs/latest/logs/phase4_colcon_build.log
```

## Output

- **Build artifacts**: `build/`
- **Debian packages**: `build/dist/`
- **Build logs**: `build/logs/`
