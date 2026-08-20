# Use Autoware base CUDA image with CUDA 12.8.
# Autoware 1.9.0 dropped the amd64.env/arm64.env files; the version matrix now
# lives in ansible/roles/{cuda,tensorrt,spconv}/defaults/main.yaml. For
# humble + x86_64 that resolves to CUDA 12.8, TensorRT 10.8.0.43-1+cuda12.8,
# spconv 2.3.8 / cumm 0.5.3 -- i.e. unchanged from 1.7.1.
FROM ghcr.io/autowarefoundation/autoware-base:cuda-latest

# Set up CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda
ENV CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# Configure the locale and timezone
RUN apt update -y && \
    apt install -y locales && \
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    locale-gen && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN ln -snf /usr/share/zoneinfo/Asia/Taipei /etc/localtime && \
    echo Asia/Taipei > /etc/timezone

# Configure AutonomouStuff APT repository for pacmod packages
RUN apt update -y && \
    apt install -y apt-transport-https && \
    rm -rf /var/lib/apt/lists/*
RUN echo "deb [trusted=yes] https://s3.amazonaws.com/autonomoustuff-repo/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/autonomoustuff-public.list > /dev/null

# Install additional ROS2 packages and development tools
RUN apt update -y && \
    apt install -y \
        ros-humble-rmw-cyclonedds-cpp \
        python3-rosdep \
        python3-colcon-common-extensions \
        python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# Set up ROS2 Python path (needed for ament_package module used by CMake)
ENV PYTHONPATH=/opt/ros/humble/lib/python3.10/site-packages:${PYTHONPATH}

# Create colcon2deb setup script to source ROS environment before build
RUN echo 'source /opt/ros/humble/setup.bash' > /colcon2deb-setup.sh

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
    apt install -y ros-humble-cudnn-cmake-module ros-humble-tensorrt-cmake-module \
    && rm -rf /var/lib/apt/lists/*

# Install cuDNN, TensorRT, and CUDA development packages (headers and dev libs)
# Pin TensorRT/cuDNN versions to match the runtime libraries in the base image
# CUDA 12.8, TensorRT 10.8.0.43, cuDNN 9 (per ansible/roles/tensorrt/defaults/main.yaml)
RUN apt update -y && \
    apt install -y \
        libcudnn9-dev-cuda-12 \
        libnvinfer-dev=10.8.0.43-1+cuda12.8 \
        libnvinfer-headers-dev=10.8.0.43-1+cuda12.8 \
        libnvinfer-headers-plugin-dev=10.8.0.43-1+cuda12.8 \
        libnvinfer-plugin-dev=10.8.0.43-1+cuda12.8 \
        libnvonnxparsers-dev=10.8.0.43-1+cuda12.8 \
        libcublas-dev-12-8 \
        libcurand-dev-12-8 \
        libcusparse-dev-12-8 \
        libcusolver-dev-12-8 \
        cuda-nvrtc-dev-12-8 \
        libcufft-dev-12-8 \
        cuda-nvml-dev-12-8 \
    && rm -rf /var/lib/apt/lists/*

# Build and install acados.
#
# Autoware 1.9.0 removed universe/external/acados and universe/external/tera_renderer
# from repositories/autoware.repos; upstream now bakes acados into the builder image
# instead (docker/universe.Dockerfile runs the `acados` ansible tag and exports
# CMAKE_PREFIX_PATH / ACADOS_SOURCE_DIR / LD_LIBRARY_PATH). Reproduce that here:
# autoware_path_optimizer does find_package(acados REQUIRED) and fails to configure
# without it, which aborts the whole colcon build.
# Versions from ansible/roles/acados/defaults/main.yaml at tag 1.9.0.
ARG ACADOS_VERSION=v0.5.3
ARG ACADOS_TERA_RENDERER_VERSION=v0.2.0
RUN apt update -y && \
    apt install -y git cmake build-essential wget python3-venv \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${ACADOS_VERSION} --recursive \
        https://github.com/acados/acados.git /opt/acados && \
    mkdir -p /opt/acados/build && \
    cd /opt/acados/build && \
    cmake -DACADOS_WITH_QPOASES=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON .. && \
    make install -j"$(nproc)" && \
    rm -rf /opt/acados/.git
RUN mkdir -p /opt/acados/bin && \
    wget -q -O /opt/acados/bin/t_renderer \
        "https://github.com/acados/tera_renderer/releases/download/${ACADOS_TERA_RENDERER_VERSION}/t_renderer-${ACADOS_TERA_RENDERER_VERSION}-linux-amd64" && \
    chmod 0755 /opt/acados/bin/t_renderer
# acados Python venv. autoware_path_optimizer's codegen step invokes
# ${ACADOS_SOURCE_DIR}/.venv/bin/python3 explicitly (see src/acados_mpc/CMakeLists.txt)
# to render the MPC solver C code, so the venv path is load-bearing, not optional.
# Mirrors ansible/roles/acados/tasks/main.yaml.
RUN python3 -m venv /opt/acados/.venv && \
    /opt/acados/.venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/acados/.venv/bin/pip install --no-cache-dir casadi sympy && \
    /opt/acados/.venv/bin/pip install --no-cache-dir -e /opt/acados/interfaces/acados_template

ENV ACADOS_SOURCE_DIR=/opt/acados
ENV CMAKE_PREFIX_PATH=/opt/acados:${CMAKE_PREFIX_PATH}
ENV LD_LIBRARY_PATH=/opt/acados/lib:${LD_LIBRARY_PATH}

# Install message_filters - required by nebula_ros but sometimes not detected by rosdep
RUN apt update -y && \
    apt install -y ros-humble-message-filters \
    && rm -rf /var/lib/apt/lists/*

# Pre-install rosdep dependencies to speed up builds
COPY rosdep-packages.txt /tmp/rosdep-packages.txt
RUN apt update -y && \
    grep -v '^#' /tmp/rosdep-packages.txt | grep -v '^$' | xargs apt-get install -y --no-install-recommends || true && \
    rm -rf /var/lib/apt/lists/* /tmp/rosdep-packages.txt

# Set default process to bash
CMD ["/bin/bash"]
