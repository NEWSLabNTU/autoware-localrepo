#!/usr/bin/env python3
"""
Generate debian packaging files for autoware-theme.

Downloads theme files from official Autoware GitHub repository during build.
"""

import argparse
import os
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# Base URL for raw GitHub content
RAW_BASE_URL = "https://raw.githubusercontent.com/autowarefoundation/autoware/refs/tags/{version}/ansible/roles/qt5ct_setup/files"

# Theme files to download
THEME_FILES = [
    "autoware.qss",
    "qt5ct.conf",
]

# Icon subdirectories and their files
ICON_DIRS = {
    "active": [
        "downarrow.svg",
        "uparrow.svg",
    ],
    "disabled": [
        "branch-end.svg",
        "branch-more.svg",
        "downarrow.svg",
        "leftarrow.svg",
        "radiobutton_checked.svg",
        "radiobutton_unchecked.svg",
        "rightarrow.svg",
        "uparrow.svg",
        "vline.svg",
    ],
    "primary": [
        "add.svg",
        "branch-closed.svg",
        "branch-end.svg",
        "branch-more.svg",
        "branch-open.svg",
        "checkbox_checked_disabled.svg",
        "checkbox_checked_enabled.svg",
        "checkbox_checked_hovered.svg",
        "checkbox_checked_pressed.svg",
        "checkbox_indeterminate_disabled.svg",
        "checkbox_indeterminate_enabled.svg",
        "checkbox_indeterminate_hovered.svg",
        "checkbox_indeterminate_pressed.svg",
        "checkbox_unchecked_disabled.svg",
        "checkbox_unchecked_enabled.svg",
        "checkbox_unchecked_hovered.svg",
        "checkbox_unchecked_pressed.svg",
        "close.svg",
        "downarrow.svg",
        "float.svg",
        "leftarrow.svg",
        "minus.svg",
        "more.svg",
        "radiobutton_checked.svg",
        "radiobutton_checked_invert.svg",
        "radiobutton_unchecked.svg",
        "radiobutton_unchecked_invert.svg",
        "rightarrow.svg",
        "sizegrip.svg",
        "slider.svg",
        "splitter-horizontal.svg",
        "splitter-vertical.svg",
        "tab_close.svg",
        "toolbar-handle-horizontal.svg",
        "toolbar-handle-vertical.svg",
        "uparrow.svg",
    ],
}

# apply-autoware-theme script content
APPLY_THEME_SCRIPT = '''#!/bin/bash

# Source file
SOURCE_FILE="/opt/autoware/theme/qt5ct.conf"
# Destination directory and file
DEST_DIR="$HOME/.config/qt5ct"
DEST_FILE="$DEST_DIR/qt5ct.conf"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file $SOURCE_FILE does not exist."
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# If destination file exists, rename it to qt5ct.conf.N
if [ -f "$DEST_FILE" ]; then
    N=1
    while [ -f "$DEST_DIR/qt5ct.conf.$N" ]; do
        ((N++))
    done
    mv "$DEST_FILE" "$DEST_DIR/qt5ct.conf.$N"
    echo "Existing $DEST_FILE renamed to qt5ct.conf.$N"
fi

# Copy the source file to the destination
cp "$SOURCE_FILE" "$DEST_FILE"

# Verify the copy operation
if [ $? -eq 0 ]; then
    echo "Successfully copied $SOURCE_FILE to $DEST_FILE"
else
    echo "Error: Failed to copy $SOURCE_FILE to $DEST_FILE"
    exit 1
fi

# Set appropriate permissions for the config file
chmod 644 "$DEST_FILE"
'''


def generate_debian_files(version: str, output_dir: Path) -> None:
    """Generate debian packaging files."""
    debian_dir = output_dir / "debian"
    debian_dir.mkdir(parents=True, exist_ok=True)

    # Create source format
    source_dir = debian_dir / "source"
    source_dir.mkdir(exist_ok=True)
    (source_dir / "format").write_text("3.0 (native)\n")

    # Generate changelog
    now = datetime.now(timezone.utc)
    changelog = f"""autoware-theme ({version}-1) jammy; urgency=medium

  * Initial release
  * Qt5 theme and RViz icons for Autoware

 -- Jerry Lin <jerry73204@gmail.com>  {now.strftime('%a, %d %b %Y %H:%M:%S %z')}
"""
    (debian_dir / "changelog").write_text(changelog)

    # Generate control file
    control = """Source: autoware-theme
Section: misc
Priority: optional
Maintainer: Jerry Lin <jerry73204@gmail.com>
Build-Depends: debhelper-compat (= 13), wget, ca-certificates
Standards-Version: 4.6.2

Package: autoware-theme
Architecture: all
Depends: ${misc:Depends}, qt5ct
Description: Autoware Qt5 theme and RViz icons
 This package contains Qt5 styling and RViz icon customizations
 for Autoware visualization tools including:
  - Custom Qt5 stylesheet (autoware.qss)
  - Qt5ct configuration
  - RViz icon set with active, disabled, and primary states
"""
    (debian_dir / "control").write_text(control)

    # Generate copyright file
    copyright_text = """Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: autoware-theme
Upstream-Contact: Jerry Lin <jerry73204@gmail.com>
Source: https://github.com/autowarefoundation/autoware

Files: *
Copyright: 2024 The Autoware Foundation
License: Apache-2.0

License: Apache-2.0
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 .
     http://www.apache.org/licenses/LICENSE-2.0
 .
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
"""
    (debian_dir / "copyright").write_text(copyright_text)

    # Generate rules file with downloads
    base_url = RAW_BASE_URL.format(version=version)

    rules_lines = [
        "#!/usr/bin/make -f",
        "",
        "export DH_VERBOSE = 1",
        "",
        "%:",
        "\tdh $@",
        "",
        "override_dh_auto_build:",
        '\t@echo "Downloading theme files..."',
    ]

    # Download main theme files
    rules_lines.append("\tmkdir -p downloads")
    for filename in THEME_FILES:
        url = f"{base_url}/{filename}"
        rules_lines.append(f'\twget -q -O downloads/{filename} "{url}"')

    # Download icon directories
    for subdir, files in ICON_DIRS.items():
        rules_lines.append(f"\tmkdir -p downloads/autoware-rviz-icons/{subdir}")
        for filename in files:
            url = f"{base_url}/autoware-rviz-icons/{subdir}/{filename}"
            rules_lines.append(f'\twget -q -O downloads/autoware-rviz-icons/{subdir}/{filename} "{url}"')

    rules_lines.append('\t@echo "Downloads complete."')
    rules_lines.append("")

    # Install section
    rules_lines.extend([
        "override_dh_auto_install:",
        "\tinstall -d $(DESTDIR)/opt/autoware/theme",
        "\tinstall -m 644 downloads/autoware.qss $(DESTDIR)/opt/autoware/theme/",
        "\tinstall -m 644 downloads/qt5ct.conf $(DESTDIR)/opt/autoware/theme/",
        "\tcp -r downloads/autoware-rviz-icons $(DESTDIR)/opt/autoware/theme/",
        "\tinstall -d $(DESTDIR)/usr/bin",
        "\tinstall -m 755 apply-autoware-theme $(DESTDIR)/usr/bin/",
        "",
        "override_dh_auto_clean:",
        "\trm -rf downloads/",
        "",
    ])

    rules_content = "\n".join(rules_lines)
    rules_file = debian_dir / "rules"
    rules_file.write_text(rules_content)
    rules_file.chmod(0o755)

    # Create apply-autoware-theme script
    apply_script = output_dir / "apply-autoware-theme"
    apply_script.write_text(APPLY_THEME_SCRIPT)
    apply_script.chmod(0o755)

    # Count files
    total_files = len(THEME_FILES) + sum(len(files) for files in ICON_DIRS.values())
    print(f"Generated debian files for autoware-theme {version}")
    print(f"  Theme files: {len(THEME_FILES)}")
    print(f"  Icon files: {sum(len(files) for files in ICON_DIRS.values())}")
    print(f"  Total: {total_files} files to download")


def main():
    parser = argparse.ArgumentParser(
        description="Generate debian packaging for autoware-theme"
    )
    parser.add_argument(
        "-v", "--version",
        default="2025.02",
        help="Autoware version tag (default: 2025.02)"
    )
    parser.add_argument(
        "-o", "--output",
        default=".",
        help="Output directory (default: current directory)"
    )

    args = parser.parse_args()
    output_dir = Path(args.output)

    generate_debian_files(args.version, output_dir)


if __name__ == "__main__":
    main()
