#!/bin/bash
set -euo pipefail

# Optional separate session. The native Control Center menu extra is the default.
if [[ "${1:-}" != "--yes" ]]; then
  cat <<'PLAN'
Optional SketchyBar session:
  • Start the installed SketchyBar with Aero Blue's own configuration.
  • Show a translucent capsule strip at the bottom of the screen.
  • Leave the macOS menu bar, Dock, login items and your existing config intact.
  • Stop with Control-C. No persistent service is created.
Run start-sketchybar.sh --yes to start after reviewing this plan.
PLAN
  exit 0
fi
[[ "$(uname -s)" == Darwin ]] || { printf '%s\n' 'SketchyBar requires macOS.' >&2; exit 1; }
command -v sketchybar >/dev/null || { printf '%s\n' 'SketchyBar is not installed. See docs/widgets.md; no software was installed.' >&2; exit 1; }
if /usr/bin/pgrep -x sketchybar >/dev/null; then
  printf '%s\n' 'An existing SketchyBar is running. Stop it yourself before starting this separate configuration.' >&2
  exit 1
fi
config_dir="$(cd "$(dirname "$0")" && pwd)"
exec sketchybar --config "$config_dir/sketchybarrc"
