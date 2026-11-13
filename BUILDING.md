# Building Autoware Local Repository

Instructions for building the autoware-localrepo packages from source.

## Prerequisites

- **Ubuntu 22.04** (Jammy)
- **Docker** with BuildKit support
- **colcon2deb** - ROS package to Debian converter
  ```bash
  pip install colcon2deb
  # Or from source: https://github.com/NEWSLabNTU/colcon2deb
  ```
- **Debian build tools**
  ```bash
  sudo apt install debhelper devscripts dpkg-dev fakeroot
  ```
- **just** command runner
  ```bash
  cargo install just
  # Or: sudo apt install just
  ```
- **GNU Parallel** (for meta-package builds)
  ```bash
  sudo apt install parallel
  ```

## Multi-Arch Setup (ARM64/Jetson Builds)

Building ARM64 packages on x86_64 requires QEMU emulation:

```bash
# Install QEMU
sudo apt install qemu-user-static

# Register QEMU with credential support (required for sudo in containers)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes

# Verify (should show flags: OCF)
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
```

**ASLR Workaround (Kernel ≥6.8.0-50):**

QEMU has a known issue with ASLR on newer kernels causing compiler segfaults:
```bash
# Disable ASLR before build
sudo sysctl kernel.randomize_va_space=0

# Run build...

# Re-enable ASLR after build
sudo sysctl kernel.randomize_va_space=2
```

## Build Steps

### 1. Clone Autoware Source

```bash
cd 1.5.0/amd64  # or jp62 for Jetson

# Clone Autoware workspace
git clone --branch 1.5.0-ws https://github.com/NEWSLabNTU/autoware.git source
cd source && vcs import src < autoware.repos && cd ..
```

### 2. Build ROS Packages

```bash
# Build all ROS packages (runs in Docker, takes several hours)
just ros

# Monitor progress
tail -f build/log/latest/*colcon_build.log
```

Output: `build/debs/*.deb` (450+ packages)

### 3. Build Meta-Packages

```bash
# Build meta-packages (autoware-config, autoware-data, etc.)
just meta
```

This runs `genpkg.sh` to auto-generate dependencies, then builds all meta-packages.

### 4. Build Localrepo Package

```bash
# Bundle all packages into autoware-localrepo
just localrepo
```

Output: `packages/autoware-localrepo_1.5.0-1_all.deb`

### All-in-One

```bash
just all  # Runs: ros → meta → localrepo
```

## Testing

```bash
# Test installation in clean Docker container
just test

# Run planning simulation (requires display)
just sim
```

## GPU-free (CPU-only) builds

`<version>/amd64-cpu/` and `<version>/arm64-cpu/` are generated from
`<version>/amd64/` and `<version>/arm64/` and must not be edited by hand. Make
the change in the CUDA directory, then regenerate:

```bash
scripts/derive-cpu.py 1.9.0/amd64     # writes 1.9.0/amd64-cpu; adds its source submodule if missing
scripts/derive-cpu.py --check-all     # fails if any -cpu directory has drifted
```

The script copies every tracked file except the source submodule. It then:

- builds FROM `autoware-base:<tag>` instead of `:cuda-<tag>`, and drops the
  CUDA environment, `NVCC_APPEND_FLAGS` and the cuDNN/TensorRT/CUDA library
  installs;
- names the builder image `...-cpu-builder` and the localrepo revision
  `ubuntu2204cpu` / `ubuntu2204arm64cpu`;
- makes the overrides' `make install` fall back to `cmake --install`. Without
  CUDA the GPU-only packages declare nothing to install and are packaged empty.
  colcon2deb 0.4.2 does the same for generated rules;
- tests on plain `ubuntu:22.04` with ROS-only prerequisites, asserts that no
  NVIDIA library got installed, and adds `test/smoke.sh`. `just test` runs it
  after the install test: it drives the planning simulator headless and passes
  when the vehicle moves.

Build them like any other directory, with `just all test`. Their downloaded
assets (`just download-data download-theme`) are the same files as the CUDA
sibling's.

## Build Commands Reference

| Command          | Description                                 |
|------------------|---------------------------------------------|
| `just all`       | Build everything (ros + meta + localrepo)   |
| `just ros`       | Build ROS packages via colcon2deb           |
| `just meta`      | Build meta-packages                         |
| `just localrepo` | Bundle packages into localrepo              |
| `just test`      | Test installation in Docker                 |
| `just sim`       | Run planning simulation                     |
| `just clean`     | Clean meta-package artifacts                |
| `just clean-ros` | Clean ROS build (WARNING: hours to rebuild) |

## Troubleshooting

### Permission Denied on build/

Docker creates files as root. Clean with sudo:
```bash
sudo rm -rf build/
```

### LTO Errors with CUDA Packages

Add to `debian-overrides/<package>/debian/rules`:
```makefile
export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto
```

### Debhelper Skips Build Phase

Clean stale state files:
```bash
find build/build -name "debhelper-build-stamp" -delete
find build/build -path "*/debian/.debhelper" -type d -exec rm -rf {} +
```

See [CLAUDE.md](CLAUDE.md) for detailed troubleshooting and known issues.
