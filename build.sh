#!/usr/bin/env bash
set -e
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Function to display usage information
usage() {
    echo "Usage: $0 PACKAGE_DIR OUTPUT_DIR"
    echo
    echo "  PACKAGE_DIR  The directory of Debian package files."
    echo "  OUTPUT_DIR   The directory to store output files."
    exit 1
}

find_files() {
    if [ $# -lt 1 ]; then
	return 1
    fi
    local pattern="$1"
    local dir=$(dirname "$pattern")
    local file=$(basename "$pattern")
    find "$dir" -maxdepth 1 -name "$file" -type f
}

find_one_file() {
    if [ $# -lt 1 ]; then
	return 1
    fi
    local pattern="$1"
    find_files "$pattern" | sort -r | head -n1
}

# Check if at least one argument (repo_dir) is provided
if [ $# -lt 1 ]; then
    echo "Error: PACKAGE_DIR is required." >&2
    usage
fi

# Store required arguments
packages_dir=$(realpath "$1")
shift

output_dir=$(realpath "$1")
shift

# Go to the current script dir
cd "$script_dir"

# Generate a package list with version constraints
find "$package_dir" -mindepth 1 -maxdepth 1 -type f -name '*.deb' | \
    awk '\
{
  n = split($0, path_parts, "/")
  file_name=path_parts[n]

  m = split(file_name, parts, "_")
  if (m >= 2) {
    pkg=parts[1]
    ver=parts[2]
    printf "%s=%s\n", pkg, ver
  }
}
' > autoware-runtime/packages.txt

# Build packages
parallel --lb ::: \
	 'cd autoware-runtime && makedeb -d' \
	 'cd autoware-theme && makedeb -d' \
	 'cd autoware-data && makedeb -d' \
	 'cd autoware-config && makedeb -d' \
	 'cd autoware-full && makedeb -d'

# Create a packages.tar needed by autoware-localrepo
tmp_dir="$(mktemp -d)"

(
    find_files "$package_dir/*.deb"
    find_one_file 'autoware-theme/autoware-theme_*.deb'
    find_one_file 'autoware-data/autoware-data_*.deb'
    find_one_file 'autoware-runtime/autoware-runtime_*.deb'
    find_one_file 'autoware-config/autoware-config_*.deb'
    find_one_file 'autoware-full/autoware-full_*.deb'
) | while read pkg_path; do
    echo cp -t "$tmp_dir" "$pkg_path"
done | parallel --lb


tar -cf "autoware-localrepo/packages.tar" -C "$tmp_dir" .
rm -rf "$tmp_dir"

# Build the local repository
(cd autoware-localrepo && makedeb -d)

localrepo_file=$(find $PWD/autoware-localrepo -maxdepth 1 -name '*.deb' -type f)
if [ -n "localrepo_file" ]; then
    cp -t "$output_dir" "$localrepo_file"
else
    echo 'error: unable to build a localrepo package'
    exit 1
fi
