# Test Dockerfile: Simulates clean JetPack 6.2 user installation
# 1. Start from L4T base image (JetPack 6.2 / L4T r36.4)
# 2. Install ROS 2 Humble and prerequisites
# 3. Install autoware-localrepo (sets up APT repo + provides helper scripts)
# 4. Install autoware-full
#
# JetPack 6.2 environment:
#   - L4T r36.4.x
#   - CUDA 12.6
#   - cuDNN 9.3
#   - TensorRT 10.3
FROM nvcr.io/nvidia/l4t-tensorrt:r10.3.0-runtime

ENV DEBIAN_FRONTEND=noninteractive

# =============================================================================
# Basic system setup
# =============================================================================
RUN apt-get update && apt-get install -y \
    locales \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common

# Configure locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Enable universe repository
RUN add-apt-repository universe

# =============================================================================
# Replace L4T OpenCV 4.8.0 with Ubuntu OpenCV 4.5.4
# L4T ships with OpenCV 4.8.0 but ROS packages expect Ubuntu's 4.5.4
# =============================================================================
RUN rm -rf /usr/lib/libopencv* /usr/lib/cmake/opencv4 /usr/include/opencv4 \
           /usr/local/lib/libopencv* /usr/local/lib/cmake/opencv4 /usr/local/include/opencv4 \
           /usr/share/OpenCV /usr/share/opencv4 /opt/opencv*
COPY opencv-preferences /etc/apt/preferences.d/opencv-preferences
RUN apt-get update && apt-get install -y libopencv-dev

# =============================================================================
# Install ROS 2 Humble
# =============================================================================
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu jammy main" > /etc/apt/sources.list.d/ros2.list

RUN apt-get update && apt-get install -y ros-humble-ros-base ros-humble-rmw-cyclonedds-cpp

# =============================================================================
# Add NVIDIA L4T APT sources (r36.4 for JetPack 6.2)
# =============================================================================
RUN apt-key adv --fetch-key http://repo.download.nvidia.com/jetson/jetson-ota-public.asc && \
    echo "deb https://repo.download.nvidia.com/jetson/common r36.4 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    echo "deb https://repo.download.nvidia.com/jetson/t234 r36.4 main" >> /etc/apt/sources.list.d/nvidia-l4t-apt-source.list && \
    mkdir -p /opt/nvidia/l4t-packages && \
    touch /opt/nvidia/l4t-packages/.nv-l4t-disable-boot-fw-update-in-preinstall && \
    apt-get update

# Install NVIDIA L4T runtime packages
RUN apt-get install -o DPkg::Options::="--force-confold" -y \
    nvidia-l4t-core \
    nvidia-l4t-cuda \
    libcudnn9-cuda-12

# =============================================================================
# Install SpConv and Cumm (for BEVFusion and other perception models)
# =============================================================================
RUN wget -q https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128/cumm_0.5.3_arm64-jetson.deb && \
    wget -q https://github.com/autowarefoundation/spconv_cpp/releases/download/spconv_v2.3.8%2Bcumm_v0.5.3%2Bcu128/spconv_2.3.8_arm64-jetson.deb && \
    apt-get install -y ./cumm_0.5.3_arm64-jetson.deb ./spconv_2.3.8_arm64-jetson.deb && \
    rm -f cumm_0.5.3_arm64-jetson.deb spconv_2.3.8_arm64-jetson.deb

# =============================================================================
# Install autoware-localrepo
# =============================================================================
COPY autoware-localrepo.deb /tmp/
RUN dpkg -i /tmp/autoware-localrepo.deb && rm /tmp/autoware-localrepo.deb

# Activate DDS configuration (sysctl + multicast)
RUN /usr/share/autoware/activate-dds-config.sh

# Install autoware-full (pulls all Autoware packages from local repo)
RUN apt-get update && apt-get install -y autoware-full

# =============================================================================
# Verify installation
# =============================================================================
RUN bash -c 'source /opt/autoware/1.5.0/setup.bash && \
    echo "Environment loaded successfully" && \
    echo "AUTOWARE_HOME=$AUTOWARE_HOME" && \
    echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION" && \
    echo "Autoware packages: $(ros2 pkg list 2>/dev/null | grep -c autoware)"'

RUN echo "Installation test completed successfully!"
