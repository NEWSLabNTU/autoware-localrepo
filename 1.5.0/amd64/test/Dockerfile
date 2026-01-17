# Test Dockerfile: Simulates clean user installation
# 1. Install autoware-localrepo (sets up APT repo + provides setup script)
# 2. Run setup-prerequisites.sh to install prerequisites
# 3. Install autoware-full
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Step 1: Install autoware-localrepo (works on fresh system, no dependencies)
COPY autoware-localrepo.deb /tmp/
RUN dpkg -i /tmp/autoware-localrepo.deb && rm /tmp/autoware-localrepo.deb

# Step 2: Run prerequisites setup script (installs ROS2, CUDA libs, etc.)
RUN /usr/share/autoware/setup-prerequisites.sh

# Step 3: Install autoware-full (pulls all Autoware packages from local repo)
RUN apt-get update && apt-get install -y autoware-full

# Verify setup.bash works and ros2 can see packages
RUN bash -c 'source /opt/autoware/1.5.0/setup.bash && \
    echo "Environment loaded successfully" && \
    echo "AUTOWARE_HOME=$AUTOWARE_HOME" && \
    echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION" && \
    echo "Autoware packages: $(ros2 pkg list 2>/dev/null | grep -c autoware)"'

RUN echo "Installation test completed successfully!"
