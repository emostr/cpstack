#!/usr/bin/env bash
# Packs build/CPStack.app into build/CPStack-<version>.dmg with a custom window
# (background, icon layout, Applications shortcut). Uses dmgbuild, which writes
# the Finder layout directly — no AppleScript, so it also works on CI runners.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/CPStack.app"
VENV="$BUILD/.venv"
ASSETS="$BUILD/dmg-assets"

[[ -d "$APP" ]] || "$ROOT/Scripts/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$BUILD/CPStack-$VERSION.dmg"

if [[ ! -x "$VENV/bin/dmgbuild" ]]; then
  echo "▸ Installing dmgbuild into build/.venv…"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.5"
fi

echo "▸ Rendering window background…"
swift "$ROOT/Scripts/make-dmg-background.swift" "$ASSETS" > /dev/null
tiffutil -cathidpicheck "$ASSETS/background.png" "$ASSETS/background@2x.png" -out "$ASSETS/background.tiff" 2> /dev/null

echo "▸ Building disk image…"
rm -f "$DMG"
"$VENV/bin/dmgbuild" \
  -s "$ROOT/Scripts/dmg-settings.py" \
  -D app="$APP" \
  -D background="$ASSETS/background.tiff" \
  -D icon="$ROOT/Resources/AppIcon.icns" \
  "CPStack" "$DMG"

if [[ -n "${CODESIGN_IDENTITY:-}" && "${CODESIGN_IDENTITY}" != "-" ]]; then
  codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG"
fi

echo "✓ $DMG"
