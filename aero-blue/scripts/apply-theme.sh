#!/bin/bash
source "$(dirname "$0")/common.sh"
aero_confirm 'Plan: back up current wallpaper and three Dock preferences (tile size, magnification, autohide); apply the selected wallpaper to connected displays and those Dock preferences; restart Dock. No app bundles, cursor resources, security settings, or other preferences will be modified.' "$@"
exec "$AERO_PYTHON" "$AERO_SCRIPT_DIR/aero.py" apply --yes "$@"
