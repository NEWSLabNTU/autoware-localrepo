# Use Autoware base CUDA image with TensorRT 10.8.0, CUDA 12.4, cuDNN 8.9.7
# This image is maintained by Autoware Foundation and matches amd64.env requirements
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
# Pin TensorRT/cuDNN versions to match the runtime libraries installed in the base image
# TensorRT 10.8.0.43-1+cuda12.8, cuDNN 8.9.7, CUDA 12.4
RUN apt update -y && \
    apt install -y \
        libcudnn8-dev=8.9.7.29-1+cuda12.2 \
        libnvinfer-dev=10.8.0.43-1+cuda12.8 \
        libnvinfer-headers-dev=10.8.0.43-1+cuda12.8 \
        libnvinfer-headers-plugin-dev=10.8.0.43-1+cuda12.8 \
        libnvinfer-plugin-dev=10.8.0.43-1+cuda12.8 \
        libnvonnxparsers-dev=10.8.0.43-1+cuda12.8 \
        libcublas-dev-12-4 \
        libcurand-dev-12-4 \
        libcusparse-dev-12-4 \
        libcusolver-dev-12-4 \
        cuda-nvrtc-dev-12-4 \
        libcufft-dev-12-4 \
        cuda-nvml-dev-12-4 \
    && rm -rf /var/lib/apt/lists/*

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
