# Test Dockerfile: Simulates clean user installation
# 1. Run setup-prerequisites.sh first (cached layer when prerequisites unchanged)
# 2. Install autoware-localrepo (sets up APT repo + provides helper scripts)
# 3. Install autoware-full-1-9-0
#
# Uses NVIDIA CUDA base image for libcudart.so (CUDA runtime)
# Additional libraries (cuDNN, TensorRT) are installed by setup-prerequisites.sh
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Step 1: Install prerequisites FIRST (separate layer for better caching)
# Installs: ROS 2 Humble, cuDNN, TensorRT, SpConv/Cumm
# Use -y to skip interactive prompts and install everything
# This is a hack - copy the script separately so it doesn't depend on autoware-localrepo.deb
COPY setup-prerequisites.sh /tmp/
RUN chmod +x /tmp/setup-prerequisites.sh && /tmp/setup-prerequisites.sh -y && rm -f /tmp/setup-prerequisites.sh

# Step 2: Install autoware-localrepo. It is the single APT source that provides
# every package, so there is nothing else to dpkg -i here.
COPY autoware-localrepo.deb /tmp/
RUN dpkg -i /tmp/autoware-localrepo.deb && rm /tmp/autoware-localrepo.deb

# Step 3: Install autoware-full-1-9-0 (pulls all Autoware packages from the
# local repo; the ML models are downloaded separately, below)
RUN apt-get update && apt-get install -y autoware-full-1-9-0

# Step 4: Activate DDS configuration (sysctl + multicast).
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

# Verify setup.bash and autoware-env.bash work, and ros2 can see packages
RUN bash -c 'source /opt/autoware/1.9.0/setup.bash && \
    source /opt/autoware/1.9.0/autoware-env.bash && \
    echo "Environment loaded successfully" && \
    echo "AUTOWARE_HOME=$AUTOWARE_HOME" && \
    echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION" && \
    echo "CYCLONEDDS_URI=$CYCLONEDDS_URI" && \
    echo "Autoware packages: $(ros2 pkg list 2>/dev/null | grep -c autoware)"'

RUN echo "Installation test completed successfully!"
