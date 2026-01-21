# Test Dockerfile: Simulates clean user installation
# 1. Run setup-prerequisites.sh first (cached layer when prerequisites unchanged)
# 2. Install autoware-localrepo (sets up APT repo + provides helper scripts)
# 3. Install autoware-full-1-5-0
#
# Uses NVIDIA CUDA base image for libcudart.so (CUDA runtime)
# Additional libraries (cuDNN, TensorRT) are installed by setup-prerequisites.sh
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Step 1: Install prerequisites FIRST (separate layer for better caching)
# Installs: ROS 2 Humble, cuDNN, TensorRT, SpConv/Cumm
# Use -y to skip interactive prompts and install everything
# This is a hack - copy the script separately so it doesn't depend on autoware-localrepo.deb
COPY setup-prerequisites.sh /tmp/
RUN chmod +x /tmp/setup-prerequisites.sh && /tmp/setup-prerequisites.sh -y && rm /tmp/setup-prerequisites.sh

# Step 2: Install autoware-localrepo (sets up local APT repo)
COPY autoware-localrepo.deb /tmp/
RUN dpkg -i /tmp/autoware-localrepo.deb && rm /tmp/autoware-localrepo.deb

# Step 3: Activate DDS configuration (sysctl + multicast)
RUN /usr/share/autoware/activate-dds-config.sh

# Step 4: Install autoware-full-1-5-0 (pulls all Autoware packages from local repo)
RUN apt-get update && apt-get install -y autoware-full-1-5-0

# Verify setup.bash works and ros2 can see packages
RUN bash -c 'source /opt/autoware/1.5.0/setup.bash && \
    echo "Environment loaded successfully" && \
    echo "AUTOWARE_HOME=$AUTOWARE_HOME" && \
    echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION" && \
    echo "Autoware packages: $(ros2 pkg list 2>/dev/null | grep -c autoware)"'

RUN echo "Installation test completed successfully!"
