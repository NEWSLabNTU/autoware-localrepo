# Autoware 2.1.0's own CUDA base image for Jazzy (Ubuntu 24.04), pinned to the
# release. The version matrix lives in
# ansible/roles/{cuda,tensorrt,spconv}/defaults/main.yaml; for jazzy it is
# CUDA 13.0, TensorRT 10.13.3.9-1+cuda13.0, spconv 2.3.8 / cumm 0.5.3 (cu130).
# Generic arm64 server build (SBSA: Grace Hopper, Ampere Altra + NVIDIA GPU,
# A100/H100 PCIe on aarch64). NOT for Jetson.
#
# Same base image as amd64: the tag is a multi-arch manifest. Unlike Humble,
# the TensorRT pin is the amd64 one: NVIDIA's ubuntu2404/sbsa apt repository
# carries 10.13.3.9-1+cuda13.0 (ubuntu2204/sbsa stops at 10.3).
FROM ghcr.io/autowarefoundation/autoware:base-cuda-devel-jazzy-2.1.0

# Set up CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda
ENV CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# Data-center GPU kernels. The CUDA packages hardcode their -gencode list
# (sm_75/86/87/89/101/120 plus compute_120 PTX), which leaves out the GPUs an
# arm64 server carries: A100 (sm_80) and H100/GH200 (sm_90). PTX only JITs
# forward, so compute_120 cannot run on either. nvcc appends this to every
# invocation, in colcon's pass and in debian/rules alike, so no package source
# is patched.
#
# compute_75 PTX is there for the packages that set no architecture at all
# (trt_batched_nms, among others). Those used to get nvcc's default, compute_52
# PTX, which JITs anywhere; any explicit -gencode replaces that default, so
# without a PTX here they would run on sm_80/sm_90 only and fail on a T4G
# (AWS g5g, sm_75) or an RTX card. compute_75 PTX JITs on every GPU from
# Turing up.
# sm_100 (B200/GB200) SASS too, because PTX is not always enough: packages
# built with separable compilation (probabilistic_occupancy_grid_map) keep no
# PTX in the final library, so they run only where they have matching SASS.
# CUDA 13.0 still targets Turing (compute_75) and sm_100; it dropped only
# Maxwell, Pascal and Volta, which TensorRT 10 never supported.
ENV NVCC_APPEND_FLAGS="-gencode arch=compute_80,code=sm_80 -gencode arch=compute_90,code=sm_90 -gencode arch=compute_100,code=sm_100 -gencode arch=compute_75,code=compute_75"


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

# Install cuDNN, TensorRT, and CUDA development packages (headers and dev libs)
# Pin TensorRT/cuDNN versions to match the runtime libraries in the base image
# CUDA 13.0, TensorRT 10.13.3.9, cuDNN 9 (per ansible/roles/tensorrt/defaults/main.yaml)
RUN apt update -y && \
    apt install -y \
        libcudnn9-dev-cuda-13 \
        libnvinfer-dev=10.13.3.9-1+cuda13.0 \
        libnvinfer-headers-dev=10.13.3.9-1+cuda13.0 \
        libnvinfer-headers-plugin-dev=10.13.3.9-1+cuda13.0 \
        libnvinfer-plugin-dev=10.13.3.9-1+cuda13.0 \
        libnvonnxparsers-dev=10.13.3.9-1+cuda13.0 \
        libcublas-dev-13-0 \
        libcurand-dev-13-0 \
        libcusparse-dev-13-0 \
        libcusolver-dev-13-0 \
        cuda-nvrtc-dev-13-0 \
        libcufft-dev-13-0 \
        cuda-nvml-dev-13-0 \
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
