#!/usr/bin/env python3
# Copyright  Alexandre Díaz <dev@redneboa.es>
import yaml
import sys
from pathlib import Path

ADDONS_YAML_FILE = Path("/opt/odoo/addons.yaml")
REPOS_YAML_FILE = Path("/opt/odoo/repos.yaml")

def main():
    try:
        addons = yaml.safe_load(ADDONS_YAML_FILE.read_text(encoding='utf-8')) or {}
        repos = yaml.safe_load(REPOS_YAML_FILE.read_text(encoding='utf-8')) or {}
    except Exception as e:
        print(f"Error reading YAML: {e}")
        sys.exit(1)

    added = False
    for repo_name in addons.keys():
        if repo_name not in repos:
            repos[repo_name] = {
                'defaults': {'depth': '$GIT_DEPTH_MERGE'},
                'remotes': {'oca': f"https://github.com/OCA/{repo_name}.git"},
                'target': 'oca $ODOO_VERSION',
                'merges': ['oca $ODOO_VERSION'],
            }
            print(f"New OCA repo added to repos: {repo_name}")
            added = True

    if added:
        try:
            print(repos)
            REPOS_YAML_FILE.write_text(
                yaml.dump(repos, default_flow_style=False, indent=2, sort_keys=False),
                encoding='utf-8'
            )
            print(f"{REPOS_YAML_FILE} successfully updated")
        except Exception as e:
            print(f"Error writting repos.yaml: {e}")
            sys.exit(1)
    else:
        print("No new OCA repos to add")

if __name__ == "__main__":
    main()