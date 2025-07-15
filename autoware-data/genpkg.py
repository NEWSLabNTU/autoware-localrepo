#!/usr/bin/env python3
import yaml
import sys
import os
import argparse
import difflib
from pathlib import Path

def parse_ansible_yaml(file_path):
    """Parse Ansible YAML file and return tasks list"""
    try:
        with open(file_path, 'r') as file:
            data = yaml.safe_load(file)
        return data
    except Exception as e:
        print(f"Error reading YAML file: {e}", file=sys.stderr)
        return None

def extract_get_url_tasks(tasks):
    """Extract download information from Ansible tasks"""
    paths = []
    sources = []
    sha256sums = []
    noextract_files = []
    warnings = []

    for task in tasks:
        if isinstance(task, dict) and 'ansible.builtin.get_url' in task:
            get_url = task['ansible.builtin.get_url']
            url = get_url.get('url')
            dest = get_url.get('dest')
            checksum = get_url.get('checksum', '')

            # Extract filename from dest path
            parent_dir = os.path.basename(os.path.dirname(dest))
            filename = os.path.basename(dest)
            paths.append((parent_dir, filename))

            # Format source as 'filename::url'
            source = f"{filename}::{url}"
            sources.append(source)

            # Extract sha256 from checksum if present
            if checksum and checksum.startswith('sha256:'):
                sha256 = checksum.split(':', 1)[1]
                sha256sums.append(sha256)
            else:
                sha256sums.append('SKIP')
                warnings.append(f"Warning: No SHA256 checksum found for {filename}")

            # Track tar.gz files for noextract
            if filename.endswith('.tar.gz'):
                noextract_files.append(filename)

    return sources, paths, sha256sums, noextract_files, warnings

def read_pkgbuild_header(pkgbuild_path):
    """Read PKGBUILD file and extract the header portion before source="""
    header_lines = []
    with open(pkgbuild_path, 'r') as f:
        for line in f:
            if line.strip().startswith('source=('):
                break
            header_lines.append(line.rstrip())
    return '\n'.join(header_lines)

def generate_pkgbuild(header, sources, paths, sha256sums, noextract_files):
    """Generate complete PKGBUILD content"""
    # Generate package() function content
    code_sections = []
    for parent_dir, filename in paths:
        if filename.endswith('.tar.gz'):
            code = f"""    install -dm755 "$target_dir/{parent_dir}"
    tar -xf "$srcdir/{filename}" -C "$target_dir/{parent_dir}"
"""
        else:
            code = f"""    install -dm755 "$target_dir/{parent_dir}"
    install -Dm644 "$srcdir/{filename}" "$target_dir/{parent_dir}/{filename}"
"""
        code_sections.append(code)

    # Build complete PKGBUILD content
    pkgbuild_content = f"""{header}
source=(
{chr(10).join(f"    '{src}'" for src in sources)}
)
sha256sums=(
{chr(10).join(f"    '{sum}'" for sum in sha256sums)}
)"""

    if noextract_files:
        pkgbuild_content += f"""
noextract=(
{chr(10).join(f"    '{file}'" for file in noextract_files)}
)"""

    pkgbuild_content += f"""

package() {{
    target_dir="$pkgdir/opt/autoware/data"
    install -dm755 "$target_dir"

{chr(10).join(code_sections)}}}
"""

    return pkgbuild_content

def show_diff(original_content, new_content, pkgbuild_path):
    """Display unified diff between original and new content"""
    original_lines = original_content.splitlines(keepends=True)
    new_lines = new_content.splitlines(keepends=True)

    diff = difflib.unified_diff(
        original_lines,
        new_lines,
        fromfile=f'{pkgbuild_path} (current)',
        tofile=f'{pkgbuild_path} (new)',
        lineterm=''
    )

    diff_output = ''.join(diff)
    if diff_output:
        print(diff_output)
        return True
    else:
        print("No changes needed in PKGBUILD")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='Generate PKGBUILD from Ansible tasks.yaml',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  %(prog)s                    # Show diff of changes
  %(prog)s --update           # Update PKGBUILD file
  %(prog)s -t custom.yaml     # Use custom tasks file
'''
    )

    parser.add_argument(
        '-u', '--update',
        action='store_true',
        help='Update the PKGBUILD file instead of showing diff'
    )

    parser.add_argument(
        '-t', '--tasks',
        default='tasks.yaml',
        help='Path to tasks YAML file (default: tasks.yaml)'
    )

    parser.add_argument(
        '-p', '--pkgbuild',
        default='PKGBUILD',
        help='Path to PKGBUILD file (default: PKGBUILD)'
    )

    args = parser.parse_args()

    # Resolve paths relative to script directory if not absolute
    script_dir = Path(__file__).parent
    tasks_path = Path(args.tasks)
    pkgbuild_path = Path(args.pkgbuild)

    if not tasks_path.is_absolute():
        tasks_path = script_dir / tasks_path
    if not pkgbuild_path.is_absolute():
        pkgbuild_path = script_dir / pkgbuild_path

    # Check if files exist
    if not tasks_path.exists():
        print(f"Error: Tasks file not found: {tasks_path}", file=sys.stderr)
        sys.exit(1)

    if not pkgbuild_path.exists():
        print(f"Error: PKGBUILD file not found: {pkgbuild_path}", file=sys.stderr)
        sys.exit(1)

    # Parse tasks.yaml
    tasks = parse_ansible_yaml(tasks_path)
    if not tasks:
        print("Error: No valid tasks found in YAML file", file=sys.stderr)
        sys.exit(1)

    # Extract download information
    sources, paths, sha256sums, noextract_files, warnings = extract_get_url_tasks(tasks)

    # Print warnings if any
    for warning in warnings:
        print(warning, file=sys.stderr)

    # Read existing PKGBUILD
    header = read_pkgbuild_header(pkgbuild_path)
    original_content = pkgbuild_path.read_text()

    # Generate new PKGBUILD content
    new_content = generate_pkgbuild(header, sources, paths, sha256sums, noextract_files)

    # Show diff or update file
    if args.update:
        pkgbuild_path.write_text(new_content)
        print(f"Updated {pkgbuild_path}")
    else:
        has_changes = show_diff(original_content, new_content, pkgbuild_path)
        if has_changes:
            print(f"\nTo apply changes, run: {sys.argv[0]} --update")

if __name__ == "__main__":
    main()
