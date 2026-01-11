#!/bin/bash
# Copyright  Alexandre Díaz <dev@redneboa.es>

if [ $# -lt 2 ]; then
    echo "Error: You must provide the environment name (ODOO or SYSTEM) and a command"
    echo "Usage: $0 <ODOO|SYSTEM> <command>"
    exit 1
fi

ENV_UPPER=$(echo "$1" | tr '[:lower:]' '[:upper:]')

case "$ENV_UPPER" in
    "ODOO")
        VENV_PATH="/opt/odoo/.venv/bin/activate"
        ;;
    "SYSTEM")
        VENV_PATH="/home/odoo/.venv/bin/activate"
        ;;
    *)
        echo "Error: Environment must be 'ODOO' or 'SYSTEM'"
        exit 1
        ;;
esac

if [ ! -f "$VENV_PATH" ]; then
    echo "Error: Virtual environment not found at $VENV_PATH"
    exit 1
fi

[ -f "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
source "$VENV_PATH"

shift
"$@"

deactivate
