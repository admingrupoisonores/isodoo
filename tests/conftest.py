# Copyright  Alexandre Díaz <dev@redneboa.es>
# License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

import time
import pytest
from python_on_whales import DockerClient

ODOO_PORT = "8069"
IMAGE_TAG_NAME = "test:docker-isodoo"
SUBNET = "172.20.0.0/16"
GATEWAY = "172.20.0.1"
IP_ADDRESS = "172.20.0.5"


def pytest_addoption(parser):
    parser.addoption("--no-cache", action="store_true", default=False)
    parser.addoption("--odoo-version", action="store", default="6.0")


@pytest.fixture(scope="session")
def env_info(pytestconfig):
    no_cache = bool(pytestconfig.getoption("no_cache", False))
    odoo_ver = pytestconfig.getoption("odoo_version")
    return {
        "ip": IP_ADDRESS,
        "ports": {
            "odoo": ODOO_PORT,
        },
        "options": {
            "no_cache": no_cache,
            "odoo_version": odoo_ver,
        },
    }


@pytest.fixture(scope="session")
def docker_build(env_info):
    docker = DockerClient()
    docker.build(
        ".",
        build_args={
            "ODOO_VERSION": env_info["options"]["odoo_version"],
        },
        tags=IMAGE_TAG_NAME,
        cache=not env_info["options"]["no_cache"],
        target="isodoo-core",
    )
    return docker


@pytest.fixture(scope="session")
def docker_odoo(docker_build, env_info):
    container = None
    network = None
    try:
        if not docker_build.network.exists("pytest-odoo-network"):
            network = docker_build.network.create(
                "pytest-odoo-network",
                driver="bridge",
                subnet=SUBNET,
                gateway=GATEWAY,
            )
        container = docker_build.container.run(
            IMAGE_TAG_NAME,
            networks=["pytest-odoo-network"],
            ip=IP_ADDRESS,
            envs={
                "ODOO_VERSION": env_info["options"]["odoo_version"],
                "OCONF_log_level": "debug",
                "OCONF_db_filter": "odoodb$",
                "OCONF_db_user": "odoo",
                "OCONF_db_password": "odoo",
                "OCONF_db_host": "odoo-db",
                "OCONF_db_name": "odoodb",
                "OCONF_proxy_mode": "false",
            },
            name="isodoo-pytest",
            remove=True,
            detach=True,
        )
        time.sleep(20)  # Wait for service. FIXME: found a better way...
        yield container
    finally:
        if container:
            docker_build.container.kill(container)
            time.sleep(5)  # Wait for docker
        if network:
            docker_build.network.remove("pytest-odoo-network")
