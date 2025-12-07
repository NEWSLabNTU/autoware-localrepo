#!/usr/bin/env python3
"""Generate debian/ directory for autoware-data package from tasks.yaml."""

import yaml
import sys
import os
import argparse
import urllib.request
from pathlib import Path
from datetime import datetime

PACKAGE_NAME = "autoware-data"
MAINTAINER = "Jerry Lin <jerry73204@gmail.com>"
DESCRIPTION = "Autoware ML model data files"
INSTALL_DIR = "/opt/autoware/data"

# URL template for downloading tasks.yaml from Autoware repo
TASKS_URL_TEMPLATE = "https://raw.githubusercontent.com/autowarefoundation/autoware/refs/tags/{version}/ansible/roles/artifacts/tasks/main.yaml"


def download_tasks_yaml(version, output_path):
    """Download tasks.yaml from Autoware GitHub repository."""
    url = TASKS_URL_TEMPLATE.format(version=version)
    print(f"Downloading tasks.yaml from {url}...")
    try:
        with urllib.request.urlopen(url) as response:
            content = response.read().decode('utf-8')
        output_path.write_text(content)
        print(f"Saved to {output_path}")
        return True
    except urllib.error.HTTPError as e:
        print(f"Error: Failed to download tasks.yaml: {e}", file=sys.stderr)
        return False
    except urllib.error.URLError as e:
        print(f"Error: Network error: {e}", file=sys.stderr)
        return False


def parse_ansible_yaml(file_path):
    """Parse Ansible YAML file and return tasks list."""
    try:
        with open(file_path, 'r') as file:
            data = yaml.safe_load(file)
        return data
    except Exception as e:
        print(f"Error reading YAML file: {e}", file=sys.stderr)
        return None


def extract_downloads(tasks):
    """Extract download information from Ansible tasks."""
    downloads = []

    for task in tasks:
        if isinstance(task, dict) and 'ansible.builtin.get_url' in task:
            get_url = task['ansible.builtin.get_url']
            url = get_url.get('url')
            dest = get_url.get('dest')
            checksum = get_url.get('checksum', '')

            # Extract path components
            # dest looks like: {{ data_dir }}/subdir/filename
            dest_path = dest.replace('{{ data_dir }}/', '')
            parent_dir = os.path.dirname(dest_path)
            filename = os.path.basename(dest_path)

            # Extract sha256 from checksum
            sha256 = ''
            if checksum and checksum.startswith('sha256:'):
                sha256 = checksum.split(':', 1)[1]

            downloads.append({
                'url': url,
                'filename': filename,
                'parent_dir': parent_dir,
                'dest_path': dest_path,
                'sha256': sha256,
                'is_tarball': filename.endswith('.tar.gz'),
            })

    return downloads


def generate_control():
    """Generate debian/control content."""
    return f"""Source: {PACKAGE_NAME}
Section: misc
Priority: optional
Maintainer: {MAINTAINER}
Build-Depends: debhelper-compat (= 13), wget, ca-certificates
Standards-Version: 4.6.2

Package: {PACKAGE_NAME}
Architecture: all
Depends: ${{misc:Depends}}
Description: {DESCRIPTION}
 This package contains pre-trained ML models and configuration files
 required by Autoware perception components including:
  - LiDAR-based 3D object detection models (CenterPoint, Transfusion)
  - Camera-based 2D object detection models (YOLOX)
  - Traffic light classification models
  - Semantic segmentation models
"""


def generate_rules(downloads):
    """Generate debian/rules content."""
    # Group downloads by parent directory
    download_commands = []
    install_commands = []

    for dl in downloads:
        parent = dl['parent_dir']
        filename = dl['filename']
        url = dl['url']
        dest_path = dl['dest_path']

        # Download command
        download_commands.append(f'\twget -q -O downloads/{dest_path} "{url}"')

        # Install command
        if dl['is_tarball']:
            install_commands.append(f'\tinstall -d $(DESTDIR){INSTALL_DIR}/{parent}')
            install_commands.append(f'\ttar -xf downloads/{dest_path} -C $(DESTDIR){INSTALL_DIR}/{parent}')
        else:
            install_commands.append(f'\tinstall -d $(DESTDIR){INSTALL_DIR}/{parent}')
            install_commands.append(f'\tinstall -m 644 downloads/{dest_path} $(DESTDIR){INSTALL_DIR}/{parent}/')

    # Get unique parent directories for mkdir
    parent_dirs = sorted(set(dl['parent_dir'] for dl in downloads))
    mkdir_commands = [f'\tmkdir -p downloads/{d}' for d in parent_dirs]

    return f"""#!/usr/bin/make -f

export DH_VERBOSE = 1

%:
\tdh $@

override_dh_auto_build:
\t@echo "Downloading model files..."
{chr(10).join(mkdir_commands)}
{chr(10).join(download_commands)}
\t@echo "Downloads complete."

override_dh_auto_install:
\tinstall -d $(DESTDIR){INSTALL_DIR}
{chr(10).join(install_commands)}

override_dh_auto_clean:
\trm -rf downloads/

override_dh_strip:
\t# Skip stripping binary files (ONNX models)

override_dh_shlibdeps:
\t# Skip shared library dependency detection
"""


def generate_changelog(version="1.0.0"):
    """Generate debian/changelog content."""
    date_str = datetime.now().strftime("%a, %d %b %Y %H:%M:%S +0000")
    return f"""{PACKAGE_NAME} ({version}-1) jammy; urgency=medium

  * Initial release
  * Package ML models for Autoware perception

 -- {MAINTAINER}  {date_str}
"""


def generate_copyright():
    """Generate debian/copyright content."""
    return f"""Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: {PACKAGE_NAME}
Upstream-Contact: {MAINTAINER}
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


def generate_source_format():
    """Generate debian/source/format content."""
    return "3.0 (native)\n"


def write_debian_files(debian_dir, downloads, version="1.0.0"):
    """Write all debian files to the specified directory."""
    debian_dir = Path(debian_dir)
    debian_dir.mkdir(parents=True, exist_ok=True)

    # Write control
    (debian_dir / 'control').write_text(generate_control())
    print(f"  Written: {debian_dir / 'control'}")

    # Write rules (needs to be executable)
    rules_path = debian_dir / 'rules'
    rules_path.write_text(generate_rules(downloads))
    rules_path.chmod(0o755)
    print(f"  Written: {rules_path}")

    # Write changelog
    (debian_dir / 'changelog').write_text(generate_changelog(version))
    print(f"  Written: {debian_dir / 'changelog'}")

    # Write copyright
    (debian_dir / 'copyright').write_text(generate_copyright())
    print(f"  Written: {debian_dir / 'copyright'}")

    # Write source/format
    source_dir = debian_dir / 'source'
    source_dir.mkdir(exist_ok=True)
    (source_dir / 'format').write_text(generate_source_format())
    print(f"  Written: {source_dir / 'format'}")


def main():
    parser = argparse.ArgumentParser(
        description='Generate debian/ directory from Ansible tasks.yaml',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  %(prog)s --download 1.5.0           # Download tasks.yaml and generate debian/
  %(prog)s --version 1.5.0            # Generate debian/ using existing tasks.yaml
  %(prog)s -o /path/to/pkg            # Generate debian/ in specified directory
  %(prog)s --download-only 1.5.0      # Only download tasks.yaml, don't generate
'''
    )

    parser.add_argument(
        '-t', '--tasks',
        default='tasks.yaml',
        help='Path to tasks YAML file (default: tasks.yaml)'
    )

    parser.add_argument(
        '-o', '--output',
        default='.',
        help='Output directory for debian/ (default: current directory)'
    )

    parser.add_argument(
        '-v', '--version',
        default='1.0.0',
        help='Package version (default: 1.0.0)'
    )

    parser.add_argument(
        '-d', '--download',
        metavar='TAG',
        help='Download tasks.yaml from Autoware repo for specified tag (e.g., 1.5.0, 2025.02)'
    )

    parser.add_argument(
        '--download-only',
        metavar='TAG',
        help='Only download tasks.yaml, do not generate debian files'
    )

    args = parser.parse_args()

    # Resolve paths
    script_dir = Path(__file__).parent
    tasks_path = Path(args.tasks)
    output_dir = Path(args.output)

    if not tasks_path.is_absolute():
        tasks_path = script_dir / tasks_path
    if not output_dir.is_absolute():
        output_dir = script_dir / output_dir

    # Handle download-only mode
    if args.download_only:
        if not download_tasks_yaml(args.download_only, tasks_path):
            sys.exit(1)
        print("\nDownload complete. Run without --download-only to generate debian files.")
        sys.exit(0)

    # Download tasks.yaml if requested
    if args.download:
        if not download_tasks_yaml(args.download, tasks_path):
            sys.exit(1)
        # Use download tag as version if not explicitly set
        if args.version == '1.0.0':
            args.version = args.download

    # Check if tasks file exists
    if not tasks_path.exists():
        print(f"Error: Tasks file not found: {tasks_path}", file=sys.stderr)
        print(f"Hint: Use --download <tag> to fetch from Autoware repo", file=sys.stderr)
        sys.exit(1)

    # Parse tasks.yaml
    print(f"Reading {tasks_path}...")
    tasks = parse_ansible_yaml(tasks_path)
    if not tasks:
        print("Error: No valid tasks found in YAML file", file=sys.stderr)
        sys.exit(1)

    # Extract download information
    downloads = extract_downloads(tasks)
    print(f"Found {len(downloads)} files to download")

    # Generate debian files
    debian_dir = output_dir / 'debian'
    print(f"\nGenerating debian files in {debian_dir}...")
    write_debian_files(debian_dir, downloads, args.version)

    print(f"\nDone! To build the package:")
    print(f"  cd {output_dir}")
    print(f"  dpkg-buildpackage -us -uc -b")


if __name__ == "__main__":
    main()
