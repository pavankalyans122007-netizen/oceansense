#!/bin/bash
source "$(dirname "$0")/common.sh"
aero_confirm 'Plan: restore managed custom icons and the active wallpaper/Dock backup, then move only marked Aero Blue app/project/widget installations into ~/Library/Application Support/Aero Blue/archives. Stop on restore conflicts. No personal files, tasks, backups, or third-party software are deleted. Remove any optional login item manually in System Settings.' "$@"
exec "$AERO_PYTHON" "$AERO_SCRIPT_DIR/aero.py" uninstall --yes "$@"
