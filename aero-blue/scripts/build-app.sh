#!/bin/bash
set -euo pipefail
AERO_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != 'Darwin' ]]; then
  printf '%s\n' 'Native build requires macOS 13+ and Xcode 15+ Command Line Tools. No app was built on this platform.' >&2
  exit 1
fi
command -v swift >/dev/null || { printf '%s\n' 'Swift is missing. Install Apple developer tools explicitly before retrying.' >&2; exit 1; }
xcode-select -p >/dev/null
swift build --package-path "$AERO_PROJECT_ROOT/swiftui-app" -c release --jobs 2
AERO_BIN_DIR="$(swift build --package-path "$AERO_PROJECT_ROOT/swiftui-app" -c release --show-bin-path)"
AERO_OUTPUT="$AERO_PROJECT_ROOT/swiftui-app/build"
mkdir -p "$AERO_OUTPUT"
AERO_STAGE="$(mktemp -d "$AERO_OUTPUT/staging.XXXXXX")"
AERO_BUNDLE="$AERO_STAGE/Aero Blue Control Center.app"
mkdir -p "$AERO_BUNDLE/Contents/MacOS" "$AERO_BUNDLE/Contents/Resources/project"
cp "$AERO_BIN_DIR/AeroBlue" "$AERO_BUNDLE/Contents/MacOS/AeroBlue"
cp "$AERO_BIN_DIR/AeroBridge" "$AERO_BUNDLE/Contents/MacOS/AeroBridge"
cp "$AERO_PROJECT_ROOT/swiftui-app/Info.plist" "$AERO_BUNDLE/Contents/Info.plist"
if [[ -f "$AERO_PROJECT_ROOT/assets/app-icon.icns" ]]; then
  cp "$AERO_PROJECT_ROOT/assets/app-icon.icns" "$AERO_BUNDLE/Contents/Resources/AeroBlue.icns"
fi
for directory in assets config scripts widgets menu-bar docs; do
  cp -R "$AERO_PROJECT_ROOT/$directory" "$AERO_BUNDLE/Contents/Resources/project/$directory"
done
cp "$AERO_PROJECT_ROOT/README.md" "$AERO_BUNDLE/Contents/Resources/project/README.md"
printf '%s\n' 'Aero Blue managed build v1' > "$AERO_BUNDLE/.aero-blue-managed"
if command -v codesign >/dev/null 2>&1; then
  # Local ad-hoc signing preserves normal macOS checks; no Gatekeeper bypass.
  codesign --force --sign - "$AERO_BUNDLE/Contents/MacOS/AeroBridge"
  codesign --force --sign - "$AERO_BUNDLE"
  codesign --verify --strict "$AERO_BUNDLE"
fi
AERO_FINAL="$AERO_OUTPUT/Aero Blue Control Center.app"
if [[ -e "$AERO_FINAL" ]]; then
  if [[ -L "$AERO_FINAL" || ! -f "$AERO_FINAL/.aero-blue-managed" ]]; then
    printf '%s\n' "Refusing to replace unowned build: $AERO_FINAL. Staged build remains at $AERO_BUNDLE." >&2
    exit 1
  fi
  mv "$AERO_FINAL" "$AERO_OUTPUT/previous-$(date +%Y%m%dT%H%M%S)-$$.app"
fi
mv "$AERO_BUNDLE" "$AERO_FINAL"
rmdir "$AERO_STAGE"
printf '%s\n' "$AERO_FINAL"
