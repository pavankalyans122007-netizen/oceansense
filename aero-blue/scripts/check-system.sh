#!/bin/bash
source "$(dirname "$0")/common.sh"
exec "$AERO_PYTHON" "$AERO_SCRIPT_DIR/aero.py" check "$@"
