#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Error: You must provide the environment name (ENVA or ENVB) and a command"
    echo "Usage: $0 <ENVA|ENVB> <command>"
    exit 1
fi

case "$1" in
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

source "$VENV_PATH"

shift
"$@"

deactivate
