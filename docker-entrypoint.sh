#!/bin/bash
set -e

# Enable NODE environment
[ -f "~/.nvm/nvm.sh" ] && . ~/.nvm/nvm.sh

# Use system python environment
.  ~/.venv/bin/activate
echo "[entrypoint] ==== SYSTEM ENV. INFO ===="
INFO_ACTIVE_USER=$(whoami 2>&1)
INFO_ACTIVE_USER_ID=$(id -u 2>&1)
INFO_ACTIVE_USER_GID=$(id -g 2>&1)
echo "[entrypoint] - Active user: $INFO_ACTIVE_USER ($INFO_ACTIVE_USER_ID:$INFO_ACTIVE_USER_GID)"
INFO_PYTHON_VERSION=$(python --version 2>&1)
echo "[entrypoint] - Python version: $INFO_PYTHON_VERSION"
if [ -f "~/.nvm/nvm.sh" ]; then
    INFO_NODE_VERSION=$(node --version 2>&1)
    echo "[entrypoint] - Node version: $INFO_NODE_VERSION"
fi
if command -v wkhtmltopdf >/dev/null 2>&1; then
    INFO_WKHTMLTOPDF_VERSION=$(wkhtmltopdf --version 2>&1)
    echo "[entrypoint] - WKHTMLTOPDF version: $INFO_WKHTMLTOPDF_VERSION"
fi
echo "[entrypoint] ==== END SYSTEM INFO ===="
if [ -n "$USER_ODOO_UID" ] && [ -n "$USER_ODOO_GID" ]; then
    echo "[entrypoint] Using custom UID ($USER_ODOO_UID) and GID ($USER_ODOO_GID)..."
    groupmod -g $USER_ODOO_GID odoo
    usermod -u $USER_ODOO_UID -g $USER_ODOO_GID odoo
    chown -R odoo:odoo /home/odoo /opt/odoo /etc/odoo /var/lib/odoo
fi
echo "[entrypoint] Generating Odoo configuration..."
generate_config /etc/odoo/odoo.conf
echo "[entrypoint] Waiting for postgres database..."
wait_for_psql --db_host=$OCONF_db_host --db_port=${OCONF_db_port:-5432} --db_user=${OCONF_db_user} --db_password=${OCONF_db_password} --timeout=30
deactivate

# Use odoo python environment
. /opt/odoo/.venv/bin/activate
echo "[entrypoint] ==== ODOO ENV. INFO ===="
INFO_ODOO_SRC_HASH=$(git -C /opt/odoo/odoo rev-parse HEAD 2>&1)
echo "[entrypoint] - Odoo source hash: $INFO_ODOO_SRC_HASH"
INFO_PYTHON_VERSION=$(python --version 2>&1)
echo "[entrypoint] - Python version: $INFO_PYTHON_VERSION"
echo "[entrypoint] ==== END ODOO INFO ===="

# Support OpenERP Web 6.x
if [ -f /etc/odoo/openerp-web.cfg ]; then
    echo "[entrypoint] Starting Odoo Server..."
    odoo --config /etc/odoo/odoo.conf &
    echo "[entrypoint] Starting Odoo Web..."
else
    echo "[entrypoint] Starting Odoo..."
fi
exec "$@"
