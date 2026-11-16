#!/usr/bin/env python3
"""Port the debian-overrides deltas to a new Autoware version's bloom output.

    scripts/port-overrides.py <version>/<arch>            write <version>/<arch>/debian-overrides
    scripts/port-overrides.py <version>/<arch> --from D   harvest from D instead of <version>/<arch>/build/packaging

debian-overrides holds targeted patches, not a frozen copy of bloom's output
(see CLAUDE.md, "Build Practices"). On a new version the old overrides go
stale, so they are rebuilt instead: run a first `just ros` with an empty
debian-overrides/ (colcon2deb writes every package's generated debian/ to
build/packaging/), then run this script. It copies each affected package's
build/packaging/<pkg>/debian/ into debian-overrides/<pkg>/debian/ and applies
the five delta types carried since 1.9.0:

  lto        debian/rules: disable LTO, which collides with CUDA fatbin symbols
             ("symbol `fatbinData' is already defined", lto-wrapper error)
  glog       debian/rules: pin agnocast to the system glog it declares; without
             it find_package(glog) picks the workspace's glog 0.6 and
             dpkg-shlibdeps cannot resolve libglog.so.1
  acados     debian/control: Depends on the autoware-acados meta-package, for
             the packages that link libacados (NEEDED, no deb provides it)
  replaces   debian/control: Replaces for packages that superseded another
  depends    debian/control: autoware_core_planning depends on
             mission-planner-universe, since the localrepo drops the core
             mission-planner deb

The package lists below are the ones for 2.1.0. Check them on each new
version: a package that no longer exists is an error here, and new CUDA
packages are not added unless their build actually fails (real deltas only).
bloom's output does not differ between arm64 and jp62 (nor did it in 1.9.0),
so one harvest can be copied to every architecture of a version.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

LTO = [
    "autoware_bevfusion", "autoware_camera_streampetr",
    "autoware_cuda_pointcloud_preprocessor", "autoware_cuda_utils",
    "autoware_lidar_centerpoint", "autoware_lidar_frnet",
    "autoware_lidar_transfusion", "autoware_probabilistic_occupancy_grid_map",
    "autoware_ptv3", "autoware_tensorrt_bevdet", "autoware_tensorrt_bevformer",
    "autoware_tensorrt_classifier", "autoware_tensorrt_common",
    "autoware_tensorrt_plugins", "autoware_tensorrt_yolox", "bevdet_vendor",
]
GLOG = ["agnocastlib", "agnocast_components", "agnocast_e2e_test", "agnocast_sample_application"]
ACADOS = ["autoware_path_optimizer", "autoware_trajectory_modifier"]
REPLACES = {  # package -> the package it replaces, without the version suffix
    "autoware_mission_planner_universe": "ros-{distro}-autoware-mission-planner",
    "autoware_overlay_rviz_plugin": "ros-{distro}-autoware-mission-details-overlay-rviz-plugin",
}
CORE_PLANNING = "autoware_core_planning"

LTO_LINES = (
    "# Disable LTO - causes conflicts with CUDA fatbin symbols\n"
    "export DEB_BUILD_MAINT_OPTIONS = hardening=+all reproducible=+fixfilepath optimize=-lto\n"
)
GLOG_COMMENT = """
# Build fix: agnocast declares the system glog (libgoogle-glog-dev,
# libglog.so.0) and colcon links that, but with the whole colcon install tree
# on CMAKE_PREFIX_PATH find_package(glog) picks the workspace's glog 0.6
# (libglog.so.1) instead, which dpkg-shlibdeps then cannot resolve. Pin the
# system package so the deb links what package.xml declares.
"""


def die(msg: str) -> None:
    sys.exit(f"error: {msg}")


def sub_once(text: str, old: str, new: str, what: str) -> str:
    n = text.count(old)
    if n != 1:
        die(f"{what}: expected the anchor once, found it {n} times")
    return text.replace(old, new)


def add_to_depends(control: str, extra: str, what: str) -> str:
    m = re.search(r"^Depends: .*$", control, re.M)
    if not m:
        die(f"{what}: no Depends line")
    return control[: m.end()] + extra + control[m.end():]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir", help="<version>[-<distro>]/<arch>, e.g. 2.1.0/arm64 or 2.1.0-jazzy/amd64")
    ap.add_argument("--from", dest="src", help="bloom output to harvest (default: <dir>/build/packaging)")
    args = ap.parse_args()

    root = Path(__file__).resolve().parent.parent
    d = root / args.dir
    m = re.fullmatch(r"(\d+\.\d+\.\d+)(?:-[a-z]+)?", args.dir.split("/")[0])
    if not m:
        die(f"{args.dir}: expected <version>[-<distro>]/<arch>")
    version = m.group(1)
    # The ROS distro names the packages (ros-humble-*, ros-jazzy-*); take it
    # from the build's own config rather than from the directory name.
    if not (d / "config.yaml").is_file():
        die(f"{args.dir}: no config.yaml")
    cm = re.search(r"^\s*ros_distro:\s*(\w+)", (d / "config.yaml").read_text(), re.M)
    if not cm:
        die(f"{d / 'config.yaml'}: no build.ros_distro")
    distro = cm.group(1)
    sfx = version.replace(".", "-")
    src = Path(args.src) if args.src else d / "build" / "packaging"
    out = d / "debian-overrides"

    pkgs = sorted(set(LTO) | set(GLOG) | set(ACADOS) | set(REPLACES) | {CORE_PLANNING})
    missing = [p for p in pkgs if not (src / p / "debian").is_dir()]
    if missing:
        die(f"no bloom output in {src} for: {' '.join(missing)}")

    for p in pkgs:
        dst = out / p / "debian"
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src / p / "debian", dst)
        rules, control = dst / "rules", dst / "control"

        if p in LTO:
            r = rules.read_text()
            r = sub_once(r, "#!/usr/bin/make -f\n", "#!/usr/bin/make -f\n\n" + LTO_LINES, f"{p} lto")
            rules.write_text(r)
        if p in GLOG:
            r = rules.read_text()
            gnu = "DEB_HOST_GNU_TYPE ?= $(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)\n"
            multi = "DEB_HOST_MULTIARCH ?= $(shell dpkg-architecture -qDEB_HOST_MULTIARCH)\n"
            r = sub_once(r, gnu, gnu + ("" if multi in r else multi) + GLOG_COMMENT, f"{p} glog")
            libdir = "\t\t-DCMAKE_INSTALL_LIBDIR=lib \\\n"
            r = sub_once(r, libdir, libdir + "\t\t-Dglog_DIR=/usr/lib/$(DEB_HOST_MULTIARCH)/cmake/glog \\\n", f"{p} glog")
            rules.write_text(r)
        if p in ACADOS:
            control.write_text(add_to_depends(control.read_text(), f", autoware-acados-{sfx}", f"{p} acados"))
        if p in REPLACES:
            c = control.read_text()
            if "\nReplaces:" in c:
                die(f"{p}: bloom output already has Replaces")
            control.write_text(add_to_depends(c, f"\nReplaces: {REPLACES[p].format(distro=distro)}-{sfx}", f"{p} replaces"))
        if p == CORE_PLANNING:
            c = control.read_text()
            c = sub_once(c, f"ros-{distro}-autoware-mission-planner-{sfx},",
                         f"ros-{distro}-autoware-mission-planner-universe-{sfx},", f"{p} depends")
            control.write_text(c)

    print(f"{out.relative_to(root)}: {len(pkgs)} overrides "
          f"({len(LTO)} lto, {len(GLOG)} glog, {len(ACADOS)} acados, {len(REPLACES)} replaces, 1 depends)")


if __name__ == "__main__":
    main()
