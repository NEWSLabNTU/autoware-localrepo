#!/bin/bash
# Setup script for Autoware Local Repository Builder
# Installs required dependencies on Ubuntu 22.04+

set -e

echo "=== Autoware Local Repository Builder Setup ==="
echo "This script will install required dependencies."
echo ""

# Ask for sudo password upfront
sudo -v

# Keep sudo alive during the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "Installing required packages..."

sudo apt update

# Build tools for Debian packaging
sudo apt install -y \
    debhelper \
    devscripts \
    fakeroot \
    dpkg-dev

# Download tools (for autoware-theme and autoware-data packages)
sudo apt install -y \
    aria2 \
    wget \
    curl

# Docker (for colcon2deb builds)
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing docker.io..."
    sudo apt install -y docker.io
    sudo usermod -aG docker $USER
    echo "NOTE: You may need to log out and back in for docker group to take effect."
fi

# Just command runner
if ! command -v just &> /dev/null; then
    echo "Installing just command runner..."
    # Try cargo first, then snap as fallback
    if command -v cargo &> /dev/null; then
        cargo install just
    else
        sudo snap install --edge --classic just
    fi
fi

# QEMU for multi-arch builds (optional but recommended)
echo ""
read -p "Install QEMU for ARM64 cross-compilation? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt install -y qemu-user-static
    echo "Registering QEMU with binfmt (credential support for sudo)..."
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes --credential yes
    echo "QEMU setup complete."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now build Autoware packages:"
echo "  cd autoware-localrepo/1.5.0/amd64"
echo "  just all    # Build everything"
echo ""
echo "For ARM64/Jetson builds, remember to disable ASLR first:"
echo "  sudo sysctl kernel.randomize_va_space=0"
echo ""
