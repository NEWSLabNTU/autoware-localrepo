# Ansible Modifications Tracking

This file tracks all modifications made to the Autoware Ansible playbooks.

## Base Version
- Source: Autoware 2025.02
- Date: 2024-01-15

## Removed Roles

1. **artifacts** - ML models provided by `autoware-data` package
2. **qt5ct_setup** - Theme provided by `autoware-theme` package  
3. **ros2** - Assume ROS 2 is pre-installed
4. **ros2_dev_tools** - Merged into dev_tools
5. **gdown** - Not needed without artifact downloads
6. **geographiclib** - Included in package dependencies

## Modified Roles

- **rmw_implementation** - Simplified to configuration only
- **build_tools** - Remove package installation, configure only
- **cuda** - Fixed versions, streamlined installation
- **tensorrt** - Fixed versions, simplified

## New Roles

- **network_setup** - Configure multicast and CycloneDDS
- **system_limits** - Apply real-time system limits
- **autoware_env** - Set up environment variables

## Modified Playbooks

- Removed all original playbooks
- Created unified `setup.yaml` playbook