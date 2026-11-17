# JetPack 7.2 (Jetson Linux r39.2, Ubuntu 24.04) builder for Jetson AGX Orin.
#
# NVIDIA publishes no container image for r39.x (nvcr.io's l4t-jetpack,
# l4t-base, l4t-cuda and l4t-tensorrt stop at r36.4), so this builds its own,
# the way NVIDIA's l4t-jetpack Dockerfile does: an Ubuntu 24.04 base plus the
# Jetson apt repository (jetson/common + jetson/som, r39.2) and the CUDA,
# cuDNN and TensorRT packages from it. The base is upstream Autoware's
# GPU-free Jazzy image (Ubuntu 24.04 with ROS 2 Jazzy and Autoware's ansible
# dependencies, the same one the -cpu builds use), so the Autoware side of the
# builder matches the other Jazzy builders.
#
# Versions, pinned to JetPack 7.2.1 (r39.2.1) and installed and held by
# packages/autoware-localrepo/src/setup-prerequisites.sh too:
#   CUDA 13.2.2, cuDNN 9.20.0.46-1, TensorRT 10.16.2.10-1+cuda13.2
FROM ghcr.io/autowarefoundation/autoware:base-jazzy-2.1.0

# Keep Ubuntu's OpenCV: the Jetson repository below has a newer libopencv-dev
# without the contrib modules (see opencv-preferences).
COPY opencv-preferences /etc/apt/preferences.d/opencv-preferences

RUN apt-get update -y && apt-get install -y curl gnupg ca-certificates && \
    curl -fsSL https://repo.download.nvidia.com/jetson/jetson-ota-public.asc \
        | gpg --dearmor -o /usr/share/keyrings/jetson-ota-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/jetson-ota-archive-keyring.gpg] https://repo.download.nvidia.com/jetson/common r39.2 main" > /etc/apt/sources.list.d/nvidia-l4t-r39.2.list && \
    echo "deb [signed-by=/usr/share/keyrings/jetson-ota-archive-keyring.gpg] https://repo.download.nvidia.com/jetson/som r39.2 main" >> /etc/apt/sources.list.d/nvidia-l4t-r39.2.list && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
        cuda-toolkit-13-2=13.2.2-1 \
        libcudnn9-cuda-13=9.20.0.46-1 \
        libcudnn9-dev-cuda-13=9.20.0.46-1 \
        libnvinfer10=10.16.2.10-1+cuda13.2 \
        libnvinfer-plugin10=10.16.2.10-1+cuda13.2 \
        libnvonnxparsers10=10.16.2.10-1+cuda13.2 \
        libnvinfer-dev=10.16.2.10-1+cuda13.2 \
        libnvinfer-headers-dev=10.16.2.10-1+cuda13.2 \
        libnvinfer-headers-plugin-dev=10.16.2.10-1+cuda13.2 \
        libnvinfer-plugin-dev=10.16.2.10-1+cuda13.2 \
        libnvonnxparsers-dev=10.16.2.10-1+cuda13.2 && \
    apt-mark hold cuda-toolkit-13-2 libcudnn9-cuda-13 libcudnn9-dev-cuda-13 \
        libnvinfer10 libnvinfer-plugin10 libnvonnxparsers10 libnvinfer-dev \
        libnvinfer-headers-dev libnvinfer-headers-plugin-dev libnvinfer-plugin-dev \
        libnvonnxparsers-dev && \
    rm -rf /var/lib/apt/lists/*

# CUDA environment. CUDAARCHS=87 (Orin) because there is no GPU at build time
# for "native" detection. The CUDA packages' own -gencode lists include sm_87;
# no NVCC_APPEND_FLAGS, since an Orin needs no other architecture.
ENV CUDA_HOME=/usr/local/cuda
ENV CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
ENV CUDAARCHS=87

# spconv / cumm for autoware_tensorrt_plugins (BEVFusion). The cu130 release
# has no "-jetson" asset as cu128 had: CUDA 13 is one aarch64 toolkit for
# SBSA and Jetson alike, so its arm64 debs are the ones for Orin too.
RUN curl -fsSLO https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu130-rev1/cumm_0.5.3_arm64.deb && \
    curl -fsSLO https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu130-rev1/spconv_2.3.8_arm64.deb && \
    apt-get update -y && apt-get install -y ./cumm_0.5.3_arm64.deb ./spconv_2.3.8_arm64.deb && \
    rm -f cumm_0.5.3_arm64.deb spconv_2.3.8_arm64.deb && rm -rf /var/lib/apt/lists/*


# acados (build dependency of autoware_path_optimizer since 1.9.0; 2.1.0's
# ansible role pins the same v0.5.3, tera renderer v0.2.0, casadi 3.7.2).
# Mirrors ansible/roles/acados: full source tree + venv + tera renderer at
# /opt/acados (the package's codegen step hardcodes that layout), plus a
# second install into /usr/local so find_package(acados) works in the
# debian/rules pass without CMAKE_PREFIX_PATH (the generated rules build
# their own prefix path).
RUN git clone --depth 1 --branch v0.5.3 --recursive https://github.com/acados/acados.git /opt/acados && \
    cmake -S /opt/acados -B /opt/acados/build \
        -DACADOS_WITH_QPOASES=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON && \
    make -C /opt/acados/build install -j"$(nproc)" && \
    cmake --install /opt/acados/build --prefix /usr/local

ADD https://github.com/acados/tera_renderer/releases/download/v0.2.0/t_renderer-v0.2.0-linux-arm64 /opt/acados/bin/t_renderer

RUN chmod 755 /opt/acados/bin/t_renderer && \
    python3 -m venv /opt/acados/.venv && \
    /opt/acados/.venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/acados/.venv/bin/pip install --no-cache-dir casadi==3.7.2 sympy && \
    /opt/acados/.venv/bin/pip install --no-cache-dir -e /opt/acados/interfaces/acados_template
ENV ACADOS_SOURCE_DIR=/opt/acados

# Configure the locale and timezone
RUN apt update -y && \
    apt install -y locales && \
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    locale-gen && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN ln -snf /usr/share/zoneinfo/Asia/Taipei /etc/localtime && \
    echo Asia/Taipei > /etc/timezone

# No AutonomouStuff APT repository: it has no noble suite (dists/noble is a
# 404, which would fail every apt update), and on Jazzy pacmod3_msgs comes from
# the ROS repository itself.

# Install additional ROS2 packages and development tools
RUN apt update -y && \
    apt install -y \
        ros-jazzy-rmw-cyclonedds-cpp \
        python3-rosdep \
        python3-colcon-common-extensions \
        python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# Build against CycloneDDS, as upstream's base image already does. Set here so
# the build does not depend on the base: with RMW_IMPLEMENTATION unset, 2.1.0's
# dependency order loads Fast DDS's config after mrt_cmake_modules' FindTinyXML2,
# and tinyxml2_vendor aborts configuring autoware_lidar_marker_localizer (seen
# on jp62). Build time only; the debs carry no RMW choice.
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Clear the base image's ENTRYPOINT. Upstream's autoware:base image ends
# /docker-entrypoint.sh with `exec gosu "${USERNAME}" "$@"`, so colcon2deb's
# entry script would run as the unprivileged aw user and fail to create its
# build user ("useradd: group '<gid>' does not exist"). The 1.x
# autoware-base:cuda-* images had a root entrypoint.
ENTRYPOINT []

# Set up ROS2 Python path (needed for ament_package module used by CMake)
ENV PYTHONPATH=/opt/ros/jazzy/lib/python3.12/site-packages:${PYTHONPATH}

# Create colcon2deb setup script to source ROS environment before build
# The base image runs Python from /opt/autoware-venv (ENV PATH, VIRTUAL_ENV;
# a venv with system site-packages). colcon2deb pip-installs rosdeb-bloom as
# root, which lands in that venv, then switches to the build user with su,
# which resets PATH to the system Python: phase 7 then fails with
# "ModuleNotFoundError: No module named 'rosdeb_bloom'". Put the venv back on
# the build user's PATH so both see the same Python.
RUN printf '%s\n' \
        'export VIRTUAL_ENV=/opt/autoware-venv' \
        'export PATH=/opt/autoware-venv/bin:$PATH' \
        'source /opt/ros/jazzy/setup.bash' > /colcon2deb-setup.sh

# Initialize rosdep
RUN rosdep init || true && rosdep update

# Install required dependencies to build Debian packages
RUN apt update -y && \
    apt install -y \
        parallel \
        fakeroot \
        debhelper \
        dh-python \
        rsync \
        sudo \
        python3-bloom \
        libgoogle-glog-dev \
        libgflags-dev \
    && rm -rf /var/lib/apt/lists/*

# Install cudnn_cmake_module and tensorrt_cmake_module for TensorRT support
RUN apt update -y && \
    apt install -y ros-jazzy-cudnn-cmake-module ros-jazzy-tensorrt-cmake-module \
    && rm -rf /var/lib/apt/lists/*

# Install message_filters - required by nebula_ros but sometimes not detected by rosdep
RUN apt update -y && \
    apt install -y ros-jazzy-message-filters \
    && rm -rf /var/lib/apt/lists/*

# Pre-install rosdep dependencies to speed up builds
COPY rosdep-packages.txt /tmp/rosdep-packages.txt
RUN apt update -y && \
    grep -v '^#' /tmp/rosdep-packages.txt | grep -v '^$' | xargs apt-get install -y --no-install-recommends || true && \
    rm -rf /var/lib/apt/lists/* /tmp/rosdep-packages.txt

# Set default process to bash
CMD ["/bin/bash"]
