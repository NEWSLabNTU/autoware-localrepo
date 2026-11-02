# Test Dockerfile: Simulates clean JetPack 6.2 user installation
# 1. Start from L4T base image (JetPack 6.2 / L4T r36.4)
# 2. Install ROS 2 Humble and prerequisites
# 3. Install autoware-localrepo (sets up APT repo + provides helper scripts)
# 4. Install autoware-full-1-9-0
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
# Add NVIDIA L4T APT sources (r36.4 for JetPack 6.2)
#
# This and the OpenCV swap above are container-only: a real JetPack 6.2 device
# already ships the L4T runtime packages, and setup-prerequisites.sh therefore
# does not install them.
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
# Run the shipped setup-prerequisites.sh -- the same script a user runs from
# /usr/share/autoware/1.9.0/ after dpkg -i'ing the localrepo. Running it here
# (rather than inlining apt commands, as the 1.7.1 jp62 test did) means
# `just test` actually exercises the documented setup procedure. It installs
# ROS 2 Humble and SpConv/Cumm; on JetPack, CUDA / cuDNN / TensorRT are
# already present, which is why the script does not offer them.
#
# Copied in separately from the .deb so this layer caches independently.
# =============================================================================
COPY setup-prerequisites.sh /tmp/
RUN chmod +x /tmp/setup-prerequisites.sh && /tmp/setup-prerequisites.sh -y && rm -f /tmp/setup-prerequisites.sh

# =============================================================================
# Install autoware-localrepo. It is the single APT source that provides every
# package, ML models included, so there is nothing else to dpkg -i here.
# =============================================================================
COPY autoware-localrepo.deb /tmp/
RUN dpkg -i /tmp/autoware-localrepo.deb && rm /tmp/autoware-localrepo.deb

# Install autoware-full-1-9-0 (pulls all Autoware packages from the local repo;
# the ML models are downloaded separately, below)
RUN apt-get update && apt-get install -y autoware-full-1-9-0

# Activate DDS configuration (sysctl + multicast).
#
# This must run AFTER autoware-full: the sysctl drop-in and multicast unit it
# activates are shipped by autoware-config, which arrives with autoware-full.
# Run earlier it finds nothing to do -- which is what this test used to do.
RUN /usr/share/autoware/1.9.0/activate-dds-config.sh

# Download ML models the way a user does: as an unprivileged user, into the
# default data_path. Only CenterPoint (the default lidar detector, ~40 MB) and
# the YabLoc tarball, to exercise download, checksum and extraction without
# pulling 2.4 GB in every test run. Root must be refused.
RUN useradd -m tester && \
    ! autoware-download-models-1-9-0 --only lidar_centerpoint && \
    su tester -c 'autoware-download-models-1-9-0 --only lidar_centerpoint,yabloc_pose_initializer && \
        autoware-download-models-1-9-0 --only lidar_centerpoint,yabloc_pose_initializer --verify && \
        test -O ~/autoware_data/lidar_centerpoint/pts_backbone_neck_head_centerpoint_tiny.onnx && \
        test -d ~/autoware_data/yabloc_pose_initializer/saved_model && \
        test -w ~/autoware_data/lidar_centerpoint' && \
    test ! -e /opt/autoware/1.9.0/data

# =============================================================================
# Verify installation
# =============================================================================
RUN bash -c 'source /opt/autoware/1.9.0/setup.bash && \
    source /opt/autoware/1.9.0/autoware-env.bash && \
    echo "Environment loaded successfully" && \
    echo "AUTOWARE_HOME=$AUTOWARE_HOME" && \
    echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION" && \
    echo "CYCLONEDDS_URI=$CYCLONEDDS_URI" && \
    echo "Autoware packages: $(ros2 pkg list 2>/dev/null | grep -c autoware)"'

RUN echo "Installation test completed successfully!"
