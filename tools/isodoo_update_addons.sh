#!/bin/bash
# Copyright  Alexandre Díaz <dev@redneboa.es>

. ~/.venv/bin/activate
cd /opt/odoo/git
[ "$AUTO_FILL_REPOS" = true ] && isodoo_auto_fill_repos
gitaggregate -c /opt/odoo/repos.auto.yaml --expand-env
chmod +x /opt/odoo/git/odoo/bin/openerp-server.py 2>/dev/null || true
chmod +x /opt/odoo/git/odoo/odoo-bin 2>/dev/null || true
isodoo_create_addons_symlinks
[ "$VERIFY_MISSING_MODULES" = true ] && isodoo_check_addons_dependencies
echo "Addons updated! Please note that external dependencies have not been downloaded in this process. To do so, you must rebuild the image."
deactivate
