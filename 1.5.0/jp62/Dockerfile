# JetPack 6.2 base image with TensorRT 10.3, CUDA 12.6, cuDNN 9.3
# L4T version: r36.4.x
FROM nvcr.io/nvidia/l4t-tensorrt:r10.3.0-devel AS base

# Update system packages
RUN apt update -y && apt upgrade -y

# Configure the locale and timezone
RUN apt install -y locales && \
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    locale-gen && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN ln -snf /usr/share/zoneinfo/Asia/Taipei /etc/localtime && echo Asia/Taipei > /etc/timezone

# Enable 'universe' repository and install basic tools
RUN apt install -y software-properties-common apt-transport-https && \
    add-apt-repository universe

# Configure AutonomouStuff APT repository for pacmod packages
RUN echo "deb [trusted=yes] https://s3.amazonaws.com/autonomoustuff-repo/ jammy main" | tee /etc/apt/sources.list.d/autonomoustuff-public.list > /dev/null

# ============================================================================
# Replace L4T OpenCV 4.8.0 with Ubuntu OpenCV 4.5.4
# The L4T base image includes OpenCV 4.8.0 (not from APT), but ROS packages
# and cv_bridge expect the Ubuntu version (4.5.4). We must:
# 1. Remove ALL L4T OpenCV files from all possible locations
# 2. Set APT preferences to ensure Ubuntu's OpenCV is always installed
# 3. Install libopencv-dev from Ubuntu repository
# ============================================================================
RUN rm -rf /usr/lib/libopencv* /usr/lib/cmake/opencv4 /usr/include/opencv4 \
           /usr/local/lib/libopencv* /usr/local/lib/cmake/opencv4 /usr/local/include/opencv4 \
           /usr/share/OpenCV /usr/share/opencv4 \
           /opt/opencv*
COPY opencv-preferences /etc/apt/preferences.d/opencv-preferences
RUN apt update && apt install -y libopencv-dev && \
    echo "Installed OpenCV version:" && dpkg -l | grep libopencv

# Install APT packages for build environment
RUN apt install -y \
    python3-venv \
    python3-pip \
    sudo \
    openssh-client \
    openssh-server \
    git \
    curl \
    wget

# Allow passwordless sudo for the sudo group (required for colcon2deb)
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install required dependencies to build Debian packages
RUN apt install -y parallel fakeroot debhelper dh-python rsync

# ============================================================================
# Install CMake from Ubuntu repository
# L4T base image has CMake 3.14.4 in /usr/local/bin which is too old for Autoware
# We remove it first, then install Ubuntu's CMake 3.22.1 which:
# - Meets Autoware's minimum CMake requirement (3.16+)
# - Has working FindCUDA module (deprecated in 3.27+, removed in 3.28+)
# ============================================================================
RUN rm -f /usr/local/bin/cmake /usr/local/bin/ctest /usr/local/bin/cpack /usr/local/bin/ccmake
RUN apt update && apt install -y cmake

# ============================================================================
# Install ROS 2 Humble following official docs
# https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html
# ============================================================================

# Add ROS 2 GPG key
RUN apt install -y curl gnupg lsb-release
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Add ROS 2 repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Update and install ROS 2 Humble
RUN apt update && apt install -y ros-humble-desktop ros-dev-tools

# Initialize rosdep
RUN rosdep init || true
RUN rosdep update

# ============================================================================
# Pre-install rosdep dependencies to speed up builds
# These packages were extracted from rosdep install --simulate
# NOTE: Some packages (python3-torch) are not available via apt on arm64/Jetson
#       We filter those out and install separately via pip if needed
# ============================================================================
COPY rosdep-packages.txt /tmp/rosdep-packages.txt
RUN apt update && \
    grep -v '^#' /tmp/rosdep-packages.txt | grep -v '^$' | xargs apt-get install -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* /tmp/rosdep-packages.txt

# Install pip packages needed for build
RUN pip3 install xmlschema yamale

# Set up ROS environment
RUN echo "source /opt/ros/humble/setup.bash" >> /etc/bash.bashrc

# Add NVIDIA L4T APT sources for Jetpack-specific packages (r36.4 for JetPack 6.2)
RUN apt-key adv --fetch-key http://repo.download.nvidia.com/jetson/jetson-ota-public.asc && \
    echo "deb https://repo.download.nvidia.com/jetson/common r36.4 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb https://repo.download.nvidia.com/jetson/t234 r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb https://repo.download.nvidia.com/jetson/ffmpeg r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    mkdir -p /opt/nvidia/l4t-packages && \
    touch /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall && \
    apt-get update -y

# Install NVIDIA L4T packages (required for Jetpack builds)
# - nvidia-l4t-core: Core libraries including CUDA driver stubs
# - nvidia-l4t-cuda: CUDA runtime libraries with DLA support
# - nvidia-l4t-dla-compiler: DLA compiler
RUN apt-get install -o DPkg::Options::="--force-confold" -y \
    nvidia-l4t-core \
    nvidia-l4t-cuda \
    nvidia-l4t-dla-compiler

# ============================================================================
# Set up CUDA environment for CMake
# The L4T base image has CUDA but CMake needs help finding it
# ============================================================================
ENV CUDA_HOME=/usr/local/cuda
ENV CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# ============================================================================
# Install spconv and cumm libraries for sparse convolution operations
# Required by autoware_tensorrt_plugins for BEVFusion and other perception models
# Pre-built packages from: https://github.com/autowarefoundation/spconv_cpp
# ============================================================================
RUN wget -q https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128/cumm_0.5.3_arm64-jetson.deb && \
    wget -q https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128/spconv_2.3.8_arm64-jetson.deb && \
    apt-get install -y ./cumm_0.5.3_arm64-jetson.deb ./spconv_2.3.8_arm64-jetson.deb && \
    rm -f cumm_0.5.3_arm64-jetson.deb spconv_2.3.8_arm64-jetson.deb

CMD ["/bin/bash"]
