# Test Dockerfile: Simulates clean user installation with prerequisites
# Prerequisites: Ubuntu 22.04 + ROS 2 Humble + NVIDIA runtime libs
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install basic tools
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    wget \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PREREQUISITE 1: ROS 2 Humble
# =============================================================================
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/ros2.list

# =============================================================================
# PREREQUISITE 2: NVIDIA CUDA Repository
# =============================================================================
RUN wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm cuda-keyring_1.1-1_all.deb

# =============================================================================
# PREREQUISITE 3: Install ROS 2 Humble base + NVIDIA runtime libs
# =============================================================================
RUN apt-get update && apt-get install -y \
    ros-humble-ros-base \
    ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# CUDA runtime libraries (matching versions from amd64.env)
RUN apt-get update && apt-get install -y \
    libcudnn8=8.9.7.29-1+cuda12.2 \
    libnvinfer10=10.8.0.43-1+cuda12.8 \
    libnvinfer-plugin10=10.8.0.43-1+cuda12.8 \
    libnvonnxparsers10=10.8.0.43-1+cuda12.8 \
    libcublas-12-4 \
    libcurand-12-4 \
    libcusparse-12-4 \
    libcusolver-12-4 \
    libcufft-12-4 \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# PREREQUISITE 4: SpConv and Cumm (from GitHub releases)
# =============================================================================
RUN wget -q https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128/cumm_0.5.3_amd64.deb \
    && wget -q https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128/spconv_2.3.8_amd64.deb \
    && dpkg -i cumm_0.5.3_amd64.deb spconv_2.3.8_amd64.deb \
    && rm -f cumm_0.5.3_amd64.deb spconv_2.3.8_amd64.deb

# =============================================================================
# TEST: Install autoware-localrepo and autoware-full
# =============================================================================
COPY autoware-localrepo.deb /tmp/
RUN dpkg -i /tmp/autoware-localrepo.deb && rm /tmp/autoware-localrepo.deb

# Install autoware-full (this pulls all Autoware packages)
RUN apt-get update && apt-get install -y autoware-full

# =============================================================================
# VERIFY: Test that setup.bash works
# =============================================================================
RUN bash -c 'source /opt/autoware/1.5.0/setup.bash && \
    echo "Environment loaded successfully" && \
    echo "AUTOWARE_HOME=$AUTOWARE_HOME" && \
    echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION" && \
    echo "CYCLONEDDS_URI=$CYCLONEDDS_URI"'

RUN echo "Installation test completed successfully!"
