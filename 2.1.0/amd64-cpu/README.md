# Autoware 2.1.0 AMD64 Build

This directory contains the colcon2deb configuration for building Autoware 2.1.0 ROS packages on x86_64.

## Configuration

### Package Naming

Packages are built with `-2-1-0` suffix to allow multiple Autoware versions to coexist:
- Example: `ros-humble-autoware-core-2-1-0` instead of `ros-humble-autoware-core`

This is configured in `config.yaml`:
```yaml
build:
  package_suffix: "2-1-0"
```

### Install Prefix

Packages install to `/opt/autoware/2.1.0` instead of the default `/opt/ros/humble`.

## Builder fixes for the 2.1.0 base image

The 2.1.0 builders start from upstream's release image instead of 1.x's
`autoware-base:cuda-latest`, and it differs in three ways that break
colcon2deb. The Dockerfile undoes each, as `../arm64/` does:

| Base image behaviour | Symptom | Fix |
|---|---|---|
| `ENTRYPOINT /docker-entrypoint.sh` ends with `exec gosu aw` | colcon2deb's entry runs unprivileged: `useradd: group '<gid>' does not exist` | `ENTRYPOINT []` |
| Python is `/opt/autoware-venv` via `ENV PATH`, which `su` drops | phase 7: `No module named 'rosdeb_bloom'` | `/colcon2deb-setup.sh` puts the venv back on PATH |
| (sets `RMW_IMPLEMENTATION`; set again so the build does not depend on it) | without it, `autoware_lidar_marker_localizer` fails in tinyxml2_vendor (seen on jp62) | `ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` |

## Patches (debian-overrides)

`debian-overrides/` holds 25 targeted patches, the 1.9.0 deltas ported to
2.1.0's bloom output by `scripts/port-overrides.py`, whose header lists them:

| Delta | Packages |
|---|---|
| LTO off in `debian/rules` (CUDA fatbin: `symbol 'fatbinData' is already defined`) | 16 CUDA packages (1.9.0's 17 less `trt_batched_nms`, gone in 2.1.0) |
| agnocast pinned to the system glog | `agnocastlib`, `agnocast_components`, `agnocast_e2e_test`, `agnocast_sample_application` |
| `Depends: autoware-acados-2-1-0` (they link libacados) | `autoware_path_optimizer`, `autoware_trajectory_modifier` |
| `Replaces:` | `autoware_mission_planner_universe`, `autoware_overlay_rviz_plugin` |
| core_planning depends on mission-planner-universe | `autoware_core_planning` |

To regenerate them, run `just ros` once with an empty `debian-overrides/`, then
`scripts/port-overrides.py 2.1.0/amd64`. bloom's output is the same for every
architecture of a version, so a harvest from one build fits the others.

## Building

```bash
# Build all packages
just ros

# Or manually
colcon2deb --workspace source --config config.yaml
```
