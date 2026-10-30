#!/bin/bash
source "$(dirname "$0")/common.sh"
aero_confirm 'Plan: verify macOS 13+ and developer tools; build locally; install Aero Blue assets under ~/Library/Application Support/Aero Blue and its app under ~/Applications. Existing managed installations are archived. No third-party software, wallpaper, Dock, cursor or login settings will be changed by installation.' "$@"
exec "$AERO_PYTHON" "$AERO_SCRIPT_DIR/aero.py" install --yes "$@"
