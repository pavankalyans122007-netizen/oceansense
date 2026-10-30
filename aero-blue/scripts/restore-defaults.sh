#!/bin/bash
source "$(dirname "$0")/common.sh"
aero_confirm 'Plan: restore the selected backup, or the original pre-theme backup, including wallpaper and the three Dock preferences; restart Dock. Restore means your previous settings, not guessed Apple factory defaults. Backups, personal files and tasks are retained.' "$@"
exec "$AERO_PYTHON" "$AERO_SCRIPT_DIR/aero.py" restore --yes "$@"
