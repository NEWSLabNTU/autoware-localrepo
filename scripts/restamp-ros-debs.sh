#!/usr/bin/env bash
# restamp-ros-debs.sh REVISION SRCDIR DESTDIR
#
# Copy every ROS deb in SRCDIR to DESTDIR with its Debian revision set to
# REVISION: ros-humble-foo-1-5-0_0.48.0-0jammy_amd64.deb becomes
# ros-humble-foo-1-5-0_0.48.0-5jammy_amd64.deb, Version 0.48.0-5jammy.
#
# Why: colcon2deb always writes revision 0 (0.48.0-0jammy). When a localrepo
# release rebuilds the ROS packages, the rebuilt debs keep the version of the
# ones already installed, so `apt upgrade` sees nothing new and leaves the old
# files in place (1.5.0-3 -> 1.5.0-humble-4: 75 packages with different files
# under the same version). Giving the ROS packages the localrepo revision
# makes a plain upgrade replace them.
#
# Only the control file's Version changes. The data member (every installed
# file) is copied byte for byte, and the inner packages pin no versions of
# each other, so nothing else refers to the old version.
#
# A justfile uses this when its set has a `ros-revision` file. Set that file
# to the localrepo revision whenever a release rebuilds the ROS packages, and
# leave it alone for a release that only rebuilds the meta packages: their
# versions must not move then, or every host reinstalls 450 unchanged packages.
set -euo pipefail

[ $# -eq 3 ] || { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
REV=$1 SRC=$2 DEST=$3
[[ "$REV" =~ ^[0-9]+$ ]] || { echo "error: revision must be a number, not $REV" >&2; exit 2; }
mkdir -p "$DEST"
SRC=$(cd "$SRC" && pwd) DEST=$(cd "$DEST" && pwd)   # ar runs in a temp dir
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

n=0
for deb in "$SRC"/*.deb; do
    [ -e "$deb" ] || continue
    old=$(dpkg-deb -f "$deb" Version)
    # <upstream>-<inc><dist>, e.g. 0.48.0-0jammy; anything else is left alone
    if [[ "$old" =~ ^(.+)-([0-9]+)([a-z]+)$ ]]; then
        new="${BASH_REMATCH[1]}-${REV}${BASH_REMATCH[3]}"
    else
        echo "warning: $(basename "$deb"): version $old not <upstream>-<n><dist>, copied as is" >&2
        cp "$deb" "$DEST/"; continue
    fi
    pkg=$(dpkg-deb -f "$deb" Package); arch=$(dpkg-deb -f "$deb" Architecture)
    out="$DEST/${pkg}_${new}_${arch}.deb"
    if [ "$new" = "$old" ]; then cp "$deb" "$out"; n=$((n + 1)); continue; fi

    d="$work/x"; rm -rf "$d"; mkdir -p "$d/c"
    (cd "$d" && ar x "$deb")
    ctrl=$(cd "$d" && ls control.tar.*); data=$(cd "$d" && ls data.tar.*)
    tar -xf "$d/$ctrl" -C "$d/c"
    sed -i "s/^Version: .*/Version: $new/" "$d/c/control"
    rm "$d/$ctrl"
    tar -C "$d/c" --owner=root:0 --group=root:0 --sort=name -caf "$d/$ctrl" .
    rm -f "$out"
    (cd "$d" && ar rc "$out" debian-binary "$ctrl" "$data")
    [ "$(dpkg-deb -f "$out" Version)" = "$new" ] || { echo "error: restamping $deb failed" >&2; exit 1; }
    n=$((n + 1))
done
echo "  restamped $n ROS packages to revision $REV"
