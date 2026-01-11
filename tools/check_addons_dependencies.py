#!/usr/bin/env python3
# Copyright  Alexandre Díaz <dev@redneboa.es>
import os
import sys
import yaml
import ast

YAML_FILE = "/opt/odoo/addons.yaml"
BASE_CORE_PATH = "/var/lib/odoo/core"
BASE_EXTRA_PATH = "/var/lib/odoo/extra"
BASE_PRIVATE_PATH = "/var/lib/odoo/private"
OPENERP_VERSIONS = ("6.0", "6.1", "7.0", "8.0", "9.0")


def get_addons_dependencies(search_path="."):
    odoo_ver = os.getenv("ODOO_VERSION", "6.0")
    manifest_name = (
        "__openerp__.py" if odoo_ver in OPENERP_VERSIONS else "__manifest__.py"
    )
    all_deps = set()
    for root, _, files in os.walk(search_path):
        if manifest_name in files:
            manifest_path = os.path.join(root, manifest_name)
            try:
                manifest_content = "{}"
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest_content = f.read().strip()
                manifest = ast.literal_eval(manifest_content)
                depends = manifest.get("depends")
                if isinstance(depends, list):
                    all_deps.update(depends)
            except Exception as e:
                print(f"Error loading {manifest_path}: {e}", file=sys.stderr)
    return list(all_deps)


def get_available_addons(search_path="."):
    final_dirs = set()
    for root, dirs, _ in os.walk(search_path):
        final_dirs.update(dirs)
    return list(final_dirs)


if __name__ == "__main__":
    addons = set()
    addons.add("base")
    addons.update(get_available_addons(BASE_CORE_PATH))
    addons.update(get_available_addons(BASE_EXTRA_PATH))
    addons.update(get_available_addons(BASE_PRIVATE_PATH))
    addons_deps = get_addons_dependencies(BASE_CORE_PATH)
    addons_deps += get_addons_dependencies(BASE_EXTRA_PATH)
    addons_deps += get_addons_dependencies(BASE_PRIVATE_PATH)
    modules_not_available = [dep for dep in addons_deps if dep not in addons]
    if len(modules_not_available) > 0:
        print("The following module dependencies must be added:")
        for addon in sorted(modules_not_available):
            print(f"   - {addon}")
        sys.exit(1)
    else:
        print("All module dependencies are satisfied")
