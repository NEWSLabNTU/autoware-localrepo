#!/bin/bash
# Autoware 1.9.0 uninstall script
#
# Usage: sudo /usr/share/autoware/1.9.0/uninstall-autoware.sh [options]
#
#   (no option)      remove the Autoware 1.9.0 packages, keep their config
#                    files and the local repository, so a reinstall is quick
#   --purge          also delete config files, the local repository package
#                    (autoware-localrepo-1-9-0) and whatever is left under
#                    /opt/autoware/1.9.0 and /usr/share/autoware/1.9.0
#   --all-versions   act on every installed Autoware version, not only 1.9.0
#                    (with --purge: remove Autoware from this machine entirely)
#   -y, --yes        do not ask for confirmation
#
# Other Autoware versions are left alone unless --all-versions is given, and
# so are the dependencies they still need. Prerequisites installed by
# setup-prerequisites.sh (ROS 2, CUDA, cuDNN, TensorRT) are never removed.
# Neither are the models each user downloaded into ~/autoware_data; the script
# lists those it finds.

# No pipefail: the listings below end in sed -n / cut, and a reader that stops
# early would make the writer fail with SIGPIPE and abort the script.
set -eu

VERSION="1.9.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PURGE=0
ALL=0
YES=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        --all-versions) ALL=1 ;;
        -y|--yes) YES=1 ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) log_error "unknown option: $arg"; exit 2 ;;
    esac
done

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

confirm() {  # $1 = question
    [ "$YES" -eq 1 ] && return 0
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy] ]]
}

# Packages dpkg knows in any state but "not installed": installed,
# half-installed after a failed run, or removed with config files left (rc).
installed_packages() {
    dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null \
        | awk '$1 !~ /^[up]n/ { print $2 }'
}

if [ "$ALL" -eq 1 ]; then
    # Every version suffix that has an Autoware package installed, e.g. 1-9-0.
    SUFFIXES=$(installed_packages \
        | sed -n -E 's/^(autoware-[a-z0-9-]+|ros-humble-[a-z0-9-]+)-([0-9]+-[0-9]+-[0-9]+)$/\2/p' \
        | sort -u)
else
    SUFFIXES="${VERSION//./-}"
fi
if [ -z "$SUFFIXES" ]; then
    log_info "No Autoware packages found."
    exit 0
fi

PKGS=""
for suffix in $SUFFIXES; do
    # Every package of the version: the ROS packages (ros-humble-*), the
    # meta-packages, autoware-data and its parts, the model downloader and
    # acados (autoware-*). The local repository package goes only with --purge.
    for p in $(installed_packages | grep -E "^(ros-humble|autoware)-.*-${suffix}\$"); do
        if [ "$p" = "autoware-localrepo-${suffix}" ] && [ "$PURGE" -eq 0 ]; then
            continue
        fi
        PKGS="$PKGS $p"
    done
done
VERSIONS=$(for s in $SUFFIXES; do printf '%s ' "${s//-/.}"; done)
COUNT=$(echo "$PKGS" | wc -w)

log_info "Autoware version(s): ${VERSIONS}"
if [ "$COUNT" -eq 0 ]; then
    log_info "No packages to remove."
else
    log_info "$COUNT package(s) to $([ "$PURGE" -eq 1 ] && echo purge || echo remove):"
    echo "$PKGS" | tr ' ' '\n' | grep . | sed -n "1,20p" | sed 's/^/    /'
    [ "$COUNT" -gt 20 ] && echo "    ... and $((COUNT - 20)) more"
    confirm "Continue?" || { log_info "Aborted."; exit 0; }

    if [ "$PURGE" -eq 1 ]; then
        # shellcheck disable=SC2086
        apt-get purge -y $PKGS
    else
        # shellcheck disable=SC2086
        apt-get remove -y $PKGS
    fi
fi

# Dependencies nothing else needs any more. apt keeps whatever another
# installed Autoware version, or a package you installed yourself, still
# depends on; this only lists what it would take, so it can be declined.
AUTOREMOVE=$(apt-get -s autoremove 2>/dev/null | awk '/^Remv /{print $2}')
if [ -n "$AUTOREMOVE" ]; then
    n=$(echo "$AUTOREMOVE" | wc -l)
    log_info "$n dependency package(s) were installed for Autoware and are no longer needed:"
    echo "$AUTOREMOVE" | sed -n "1,15p" | sed 's/^/    /'
    [ "$n" -gt 15 ] && echo "    ... and $((n - 15)) more"
    if confirm "Remove them as well (apt-get autoremove)?"; then
        if [ "$PURGE" -eq 1 ]; then
            apt-get autoremove --purge -y
        else
            apt-get autoremove -y
        fi
    fi
fi

if [ "$PURGE" -eq 1 ]; then
    for suffix in $SUFFIXES; do
        v="${suffix//-/.}"
        # What is left is unowned: caches written at run time (__pycache__),
        # the localrepo's package index. Nothing a package still ships.
        for dir in "/opt/autoware/$v" "/usr/share/autoware/$v"; do
            if [ -e "$dir" ]; then
                if dpkg -S "$dir" >/dev/null 2>&1; then
                    log_warn "$dir still belongs to an installed package; left in place"
                else
                    rm -rf -- "$dir"
                    log_info "Removed $dir"
                fi
            fi
        done
    done
    rmdir /opt/autoware /usr/share/autoware 2>/dev/null || true
    apt-get update -qq || true
fi

# Models are user data: report them, never delete them.
for home in /root /home/*; do
    for d in "$home"/autoware_data*; do
        [ -d "$d" ] || continue
        stamp=$(cat "$d/.autoware-version" 2>/dev/null || echo unknown)
        for v in $VERSIONS; do
            if [ "$stamp" = "$v" ] || [ "$stamp" = unknown ]; then
                log_warn "Models (and TensorRT engines) for Autoware $stamp remain in $d ($(du -sh "$d" 2>/dev/null | cut -f1)); delete with: rm -rf $d"
                break
            fi
        done
    done
done

echo ""
log_info "Done."
if [ "$PURGE" -eq 0 ]; then
    echo "  The local repository (autoware-localrepo-*) is still installed, so"
    echo "  'apt-get install autoware-full-<version>' works without downloading."
    echo "  Run again with --purge to remove it and everything else."
fi
