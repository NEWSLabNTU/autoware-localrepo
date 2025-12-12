FROM nvcr.io/nvidia/l4t-tensorrt:r8.6.2-devel AS base

# Update system packages
RUN apt update -y && apt upgrade -y

# Configure the locale and timezone
RUN apt install -y locales && \
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    locale-gen && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN ln -snf /usr/share/zoneinfo/Asia/Taipei /etc/localtime && echo Asia/Taipei > /etc/timezone

# Enable 'universe' repository and install basic tools
RUN apt install -y software-properties-common apt-transport-https && \
    add-apt-repository universe

# Install APT packages for build environment
RUN apt install -y \
    python3-venv \
    python3-pip \
    sudo \
    openssh-client \
    openssh-server \
    git \
    curl \
    wget

# Install required dependencies to build Debian packages
RUN apt install -y parallel fakeroot debhelper dh-python rsync

# ============================================================================
# Install CMake 3.28+ from Kitware APT repository
# L4T base image has CMake 3.14.4 which is too old for Autoware packages
# ============================================================================
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
RUN echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null
RUN apt update && apt install -y cmake

# ============================================================================
# Install ROS 2 Humble following official docs
# https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html
# ============================================================================

# Add ROS 2 GPG key
RUN apt install -y curl gnupg lsb-release
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Add ROS 2 repository
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Update and install ROS 2 Humble
RUN apt update && apt install -y ros-humble-desktop ros-dev-tools

# Initialize rosdep
RUN rosdep init || true
RUN rosdep update

# ============================================================================
# Pre-install rosdep dependencies to speed up builds
# These packages were extracted from rosdep install --simulate
# ============================================================================
COPY rosdep-packages.txt /tmp/rosdep-packages.txt
RUN apt update && \
    grep -v '^#' /tmp/rosdep-packages.txt | grep -v '^$' | xargs apt-get install -y --no-install-recommends || true && \
    rm -rf /var/lib/apt/lists/* /tmp/rosdep-packages.txt

# Install pip packages
RUN pip3 install xmlschema yamale

# Set up ROS environment
RUN echo "source /opt/ros/humble/setup.bash" >> /etc/bash.bashrc

CMD ["/bin/bash"]
