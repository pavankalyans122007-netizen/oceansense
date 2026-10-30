#!/bin/bash
# Sourced only by wrappers. No automatic package installation or privilege escalation.
set -euo pipefail
AERO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v python3 >/dev/null 2>&1; then
  AERO_PYTHON="$(command -v python3)"
elif command -v xcrun >/dev/null 2>&1 && xcrun --find python3 >/dev/null 2>&1; then
  AERO_PYTHON="$(xcrun --find python3)"
else
  printf '%s\n' 'Python 3.9+ is required. Install Xcode Command Line Tools or Python from python.org after reviewing their installers.' >&2
  exit 1
fi
"$AERO_PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' || {
  printf '%s\n' 'Python 3.9 or later is required.' >&2
  exit 1
}

aero_confirm() {
  local plan="$1"
  shift
  printf '%s\n' "$plan" >&2
  for arg in "$@"; do
    if [[ "$arg" == '--yes' ]]; then return 0; fi
  done
  if [[ ! -t 0 ]]; then
    printf '%s\n' 'No changes made. Review this plan and rerun with --yes to authorize.' >&2
    return 1
  fi
  local answer
  read -r -p 'Continue? Type yes: ' answer
  [[ "$answer" == 'yes' ]] || { printf '%s\n' 'Cancelled.' >&2; return 1; }
}
