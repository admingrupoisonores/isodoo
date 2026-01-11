#!/usr/bin/env python3
# Copyright  Alexandre Díaz <dev@redneboa.es>
import yaml
import os
import logging

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

YAML_FILE = "/opt/odoo/addons.yaml"
SOURCE_BASE_PATH = "/opt/odoo"
DEST_BASE_CORE_PATH = "/var/lib/odoo/core"
DEST_BASE_EXTRA_PATH = "/var/lib/odoo/extra"


def load_yaml(file_path):
    try:
        with open(file_path, "r") as file:
            return yaml.safe_load(file) or {}
    except FileNotFoundError:
        logger.warning(
            f"The file {file_path} was not found. Will process all repositories in {SOURCE_BASE_PATH}."
        )
        return {}
    except yaml.YAMLError as e:
        logger.error(f"Error parsing the YAML file: {e}")
        raise


def get_all_modules(repo_path):
    try:
        return [
            d
            for d in os.listdir(repo_path)
            if os.path.isdir(os.path.join(repo_path, d)) and not d.startswith(".")
        ]
    except OSError as e:
        logger.warning(f"Error reading modules in {repo_path}: {e}")
        return []


def get_all_repos():
    try:
        return [
            d
            for d in os.listdir(SOURCE_BASE_PATH)
            if os.path.isdir(os.path.join(SOURCE_BASE_PATH, d))
            and not d.startswith(".")
        ]
    except OSError as e:
        logger.warning(f"Error reading repositories in {SOURCE_BASE_PATH}: {e}")
        return []


def create_symlinks(addons_config):
    os.makedirs(DEST_BASE_CORE_PATH, exist_ok=True)
    os.makedirs(DEST_BASE_EXTRA_PATH, exist_ok=True)

    all_repos = get_all_repos()

    for repo in set(list(addons_config.keys()) + all_repos):
        if repo == "odoo":
            repo_path = os.path.join(SOURCE_BASE_PATH, repo, "addons")
            dest_repo_path = DEST_BASE_CORE_PATH
        else:
            repo_path = os.path.join(SOURCE_BASE_PATH, repo)
            dest_repo_path = DEST_BASE_EXTRA_PATH

        if not os.path.exists(repo_path) or not os.path.isdir(repo_path):
            logger.warning(
                f"The repository directory {repo_path} does not exist or is not a directory. Skipping..."
            )
            continue

        # Get modules: use YAML list if specified, otherwise get all modules
        modules = addons_config.get(repo, [])
        if not modules:
            modules = get_all_modules(repo_path)
            logger.info(
                f"No modules specified for {repo} in YAML or not in YAML. Including all modules: {modules}"
            )

        if not modules:
            logger.info(f"No modules to process in repository {repo}. Skipping...")
            continue

        for module in modules:
            source_module_path = os.path.join(repo_path, module)
            dest_module_path = os.path.join(dest_repo_path, module)

            if not os.path.isdir(source_module_path):
                logger.warning(f"{source_module_path} is not a directory. Skipping...")
                continue

            if os.path.exists(dest_module_path):
                if os.path.islink(dest_module_path):
                    logger.info(
                        f"The symbolic link for {module} already exists at {dest_module_path}."
                    )
                    continue
                else:
                    logger.warning(
                        f"A file/directory already exists at {dest_module_path} and is not a symbolic link. Skipping..."
                    )
                    continue

            try:
                os.symlink(source_module_path, dest_module_path)
                logger.info(
                    f"Symbolic link created: {dest_module_path} -> {source_module_path}"
                )
            except OSError as e:
                logger.error(f"Error creating symbolic link for {module}: {e}")


def main():
    try:
        addons_config = load_yaml(YAML_FILE)
        create_symlinks(addons_config)
    except Exception as e:
        logger.error(f"Error running the script: {e}")
        exit(1)


if __name__ == "__main__":
    main()
