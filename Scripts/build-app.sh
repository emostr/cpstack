#!/usr/bin/env bash
# Builds CPStack.app into ./build.
#   VERSION=1.2.0          version shown in About (default: from Info.plist)
#   BUILD_NUMBER=42        CFBundleVersion (default: 1)
#   CODESIGN_IDENTITY="…"  signing identity (default: ad-hoc "-")
#   UNIVERSAL=1            arm64 + x86_64 (requires full Xcode)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/CPStack.app"
IDENTITY="${CODESIGN_IDENTITY:--}"

cd "$ROOT"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "▸ Compiling (release)…"
swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}" --show-bin-path)"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "▸ Rendering app icon…"
  swift "$ROOT/Scripts/make-icon.swift" "$ROOT/Resources/AppIcon.icns"
fi

echo "▸ Assembling CPStack.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CPStack" "$APP/Contents/MacOS/CPStack"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/Resources/"*.lproj "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

PLIST="$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION#v}" "$PLIST"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-1}" "$PLIST"

xattr -cr "$APP"
echo "▸ Signing ($IDENTITY)…"
SIGN_FLAGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]]; then
  SIGN_FLAGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --strict "$APP"

echo "✓ $APP"
