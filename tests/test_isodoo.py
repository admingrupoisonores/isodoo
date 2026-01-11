# Copyright  Alexandre Díaz <dev@redneboa.es>
import requests

OLDER_VERSIONS = ("6.0", "6.1", "7.0")
OPENERP_VERSIONS = ("6.0", "6.1", "7.0", "8.0", "9.0")
ODOO_VERSIONS = ("10.0", "11.0", "12.0", "13.0", "14.0", "15.0", "16.0", "17.0", "18.0", "19.0")


class TestIsOdooContainer:
    def test_odoo_version(self, exec_docker, env_info):
        version = exec_docker("odoo", ["odoo", "--version"])
        assert env_info["options"]["odoo_version"] in version

    def test_odoo_pip_dependencies(self, exec_docker):
        pip_info = exec_docker("odoo", ["cat", "/opt/odoo/pip.txt"])
        assert "test-pip-install" in pip_info
        pip_info = exec_docker("odoo", ["pip", "show", "pip"])
        assert "not found" not in pip_info
        pip_info = exec_docker("odoo", ["pip", "show", "test-pip-install"])
        assert "not found" not in pip_info
        pip_info = exec_docker("odoo", ["pip", "show", "invented1234"])
        assert not pip_info

    def test_odoo_apt_dependencies(self, exec_docker):
        apt_info = exec_docker("odoo", ["cat", "/opt/odoo/apt.txt"])
        assert "hello" in apt_info
        apt_info = exec_docker("odoo", ["dpkg-query", "-W", "-f='${Status}\n'", "apt"])
        assert "ok installed" in apt_info
        apt_info = exec_docker("odoo", ["dpkg-query", "-W", "-f='${Status}\n'", "hello"])
        assert "ok installed" in apt_info
        apt_info = exec_docker("odoo", ["dpkg-query", "-W", "-f='${Status}\n'", "invented1234"])
        assert not apt_info

    def test_odoo_npm_dependencies(self, exec_docker, env_info):
        odoo_ver = env_info["options"]["odoo_version"]
        if odoo_ver in OLDER_VERSIONS:
            return None
        npm_info = exec_docker("odoo", ["cat", "/opt/odoo/npm.txt"])
        assert "mirlo" in npm_info
        npm_info = exec_docker("odoo", ["npm", "ls", "-g"])
        assert "npm" in npm_info
        assert "mirlo" in npm_info
        assert "invented1234" not in npm_info

    def test_odoo_repos(self, exec_docker):
        repo_info = exec_docker("odoo", ["cat", "/opt/odoo/repos.yaml"])
        assert "odoo" in repo_info
        repo_info = exec_docker("odoo", ["ls", "/var/lib/odoo/core"])
        assert "cannot access" not in repo_info
        assert "account" in repo_info

    def test_odoo_extra_addons(self, exec_docker, env_info):
        odoo_ver = env_info["options"]["odoo_version"]
        if odoo_ver == "6.0":
            repo_info = exec_docker("odoo", ["cat", "/opt/odoo/repos.yaml"])
            assert "l10n-spain" in repo_info
            repo_info = exec_docker("odoo", ["ls", "/var/lib/odoo/extra"])
            assert "cannot access" not in repo_info
            assert "city" in repo_info
        else:
            repo_info = exec_docker("odoo", ["cat", "/opt/odoo/repos.yaml"])
            assert "reporting-engine" in repo_info
            repo_info = exec_docker("odoo", ["ls", "/var/lib/odoo/extra"])
            assert "cannot access" not in repo_info
            assert "report_xls" in repo_info

    def test_odoo_private_addons(self, exec_docker):
        addons_info = exec_docker("odoo", ["ls", "/var/lib/odoo/private"])
        assert "cannot access" not in addons_info
        assert "demo_addon" in addons_info
        def install_module(modname):
            return exec_docker("odoo", [
                "odoo", 
                "-c", 
                "/etc/odoo/odoo.conf", 
                "-i", 
                modname,
                "--stop-after-init",
            ])
        addons_info = install_module("invented1234")
        assert "ignored: invented1234" in addons_info
        addons_info = install_module("demo_addon")
        assert "demo_addon: creating or updating database tables" in addons_info

    def test_odoo_config(self, exec_docker):
        config_info = exec_docker("odoo", ["cat", "/etc/odoo/odoo.conf"])
        assert "db_name = odoodb" in config_info

    def test_auto_download(self, exec_docker, env_info):
        odoo_ver = env_info["options"]["odoo_version"]
        if odoo_ver == "6.0":
            return None
        pip_info = exec_docker("odoo", ["cat", "/opt/odoo/pip.txt"])
        assert "xlwt" in pip_info
        pip_info = exec_docker("odoo", ["pip", "show", 'xlwt'])
        assert "not found" not in pip_info

    def test_simple_http(self, docker_env, env_info):
        odoo_ver = env_info["options"]["odoo_version"]
        if odoo_ver in OLDER_VERSIONS:
            get_url = f"http://{env_info['ip']}:{env_info['ports']['odoo']}"
        else:
            get_url = f"http://{env_info['ip']}:{env_info['ports']['odoo']}/web/login"
        resp = requests.get(get_url)
        assert resp.status_code == 200
        projname = "openerp" if env_info["options"]["odoo_version"] in OLDER_VERSIONS else "Odoo"
        assert projname in resp.text
