#!/usr/bin/env python3
# Copyright  Alexandre Díaz <dev@redneboa.es>
import os
import sys
import ast

PIP_FILE = "/opt/odoo/pip.txt"
APT_FILE = "/opt/odoo/apt.txt"
NPM_FILE = "/opt/odoo/npm.txt"
DEST_BASE_CORE_PATH = "/var/lib/odoo/core"
DEST_BASE_EXTRA_PATH = "/var/lib/odoo/extra"
OPENERP_VERSIONS = ("6.0", "6.1", "7.0", "8.0", "9.0")


def load_existing_deps(file_path):
    """Carga deps existentes (incluso si el archivo no existe → set vacío)."""
    deps = set()
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    deps.add(line)
    return deps


def save_deps(file_path, deps):
    """Sobrescribe el archivo solo si hay contenido."""
    if deps:
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write("\n".join(sorted(deps)) + "\n")


def get_external_dependencies(search_path="."):
    odoo_ver = os.getenv("ODOO_VERSION", "6.0")
    manifest_name = (
        "__openerp__.py" if odoo_ver in OPENERP_VERSIONS else "__manifest__.py"
    )
    pip_deps = set()
    deb_deps = set()
    npm_deps = set()

    for root, _, files in os.walk(search_path, followlinks=True):
        if manifest_name in files:
            manifest_path = os.path.join(root, manifest_name)
            try:
                manifest_content = "{}"
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest_content = f.read().strip()
                manifest = ast.literal_eval(manifest_content)
                external = manifest.get("external_dependencies")
                if isinstance(external, dict):
                    pip_deps.update(external.get("python", []))
                    deb_deps.update(external.get("deb", []))
                    npm_deps.update(external.get("npm", []))
            except Exception as e:
                print(f"Error loading {manifest_path}: {e}", file=sys.stderr)

    return pip_deps, deb_deps, npm_deps


def apply_replacements(deps, replacements):
    result = set()
    for dep in deps:
        for old, new in replacements.items():
            print("Revisando:", dep, " --- ", old, " ----", new)
            if dep.startswith(old):
                dep = dep.replace(old, new, 1)
                break
        result.add(dep)
    return result


if __name__ == "__main__":
    existing_pip = load_existing_deps(PIP_FILE)
    existing_deb = load_existing_deps(APT_FILE)
    existing_npm = load_existing_deps(NPM_FILE)

    all_pip = set()
    all_deb = set()
    all_npm = set()

    for base_path in [DEST_BASE_CORE_PATH, DEST_BASE_EXTRA_PATH]:
        if os.path.exists(base_path):
            pip, deb, npm = get_external_dependencies(base_path)
            all_pip.update(pip)
            all_deb.update(deb)
            all_npm.update(npm)
        else:
            print(f"Warning: Path not found: {base_path}", file=sys.stderr)

    replacements = {}
    overrides_str = os.environ.get("EXT_DEPS_OVERRIDES", "")
    print("Deps. Contraints. Env:", overrides_str)
    if overrides_str.strip():
        for part in overrides_str.split(","):
            if ":" in part:
                old, new = part.strip().split(":", 1)
                if old:
                    replacements[old] = new

    print("Replacements:", replacements)
    new_pip = apply_replacements(all_pip, replacements)
    new_deb = apply_replacements(all_deb, replacements)
    new_npm = apply_replacements(all_npm, replacements)

    final_pip = existing_pip.union(new_pip)
    final_deb = existing_deb.union(new_deb)
    final_npm = existing_npm.union(new_npm)

    save_deps(PIP_FILE, final_pip)
    save_deps(APT_FILE, final_deb)
    save_deps(NPM_FILE, final_npm)

    added_pip = len(final_pip) - len(existing_pip)
    added_deb = len(final_deb) - len(existing_deb)
    added_npm = len(final_npm) - len(existing_npm)

    print("Dependency files updated:")
    print(f"  pip.txt: {len(final_pip)} packages (+{added_pip} added)")
    print(f"  apt.txt: {len(final_deb)} packages (+{added_deb} added)")
    print(f"  npm.txt: {len(final_npm)} packages (+{added_npm} added)")
