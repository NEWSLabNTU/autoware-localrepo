#!/usr/bin/env python3
import yaml
import sys
import os
from urllib.parse import urlparse

def parse_ansible_yaml(file_path):
    try:
        with open(file_path, 'r') as file:
            data = yaml.safe_load(file)
        return data
    except Exception as e:
        print(f"Error reading YAML file: {e}")
        return None

def extract_get_url_tasks(tasks):
    paths = []
    sources = []
    sha256sums = []
    
    for task in tasks:
        if isinstance(task, dict) and 'ansible.builtin.get_url' in task:
            get_url = task['ansible.builtin.get_url']
            url = get_url.get('url')
            dest = get_url.get('dest')
            checksum = get_url.get('checksum')
            
            # Extract filename from dest path
            parent_dir = os.path.basename(os.path.dirname(dest))
            filename = os.path.basename(dest)
            paths.append((parent_dir, filename))

            # Extract sha256 from checksum if present
            assert checksum.startswith('sha256:')
            sha256 = checksum.split(':')[-1]
            sha256sums.append(sha256)

            # Format source as 'filename::url'
            source = f"{filename}::{url}"
            sources.append(source)
                    
    return sources, sha256sums, paths

def generate_bash_arrays(sources, sha256sums, paths):
    code_sections = list()
    
    for parent_dir, filename in paths:
        if filename.endswith('.tar.gz'):
            code = f"""\
    install -dm755 "$target_dir/{parent_dir}"
    tar -xf "$srcdir/{filename}" -C "$target_dir/{parent_dir}"
"""    
        else:
            code = f"""\
    install -dm755 "$target_dir/{parent_dir}"
    install -Dm644 "$srcdir/{filename}" "$target_dir/{parent_dir}/{filename}"
"""
        code_sections.append(code)
        
    return """\
source=(
{}
)
sha256sums=(
{}
)

package() {{
{}
}}
""".format(
        '\n'.join(f"    '{src}'" for src in sources),
        '\n'.join(f"    '{digest}'" for digest in sha256sums),
        '\n'.join(code_sections),
    )

def main():
    if len(sys.argv) != 2:
        print("Usage: python transform_ansible_get_url.py <ansible_yaml_file>")
        sys.exit(1)
        
    yaml_file = sys.argv[1]
    tasks = parse_ansible_yaml(yaml_file)
    
    if not tasks:
        print("No valid tasks found in YAML file")
        sys.exit(1)
        
    sources, sha256sums, paths = extract_get_url_tasks(tasks)
    code = generate_bash_arrays(sources, sha256sums, paths)
    print(code)

if __name__ == "__main__":
    main()
