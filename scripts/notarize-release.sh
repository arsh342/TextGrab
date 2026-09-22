#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Derive version from project
VERSION="${VERSION:-}"
if [[ -z "$VERSION" ]]; then
    # Try to get from build settings first
    VERSION=$(xcodebuild -project TextGrab.xcodeproj -scheme TextGrab -showBuildSettings -configuration Release 2>/dev/null | grep -E '^\s*MARKETING_VERSION' | head -1 | sed 's/.*= //')
fi
# Fallback to Info.plist if not in build settings
if [[ -z "$VERSION" ]]; then
    VERSION=$(plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/TextGrab/Supporting Files/Info.plist" 2>/dev/null || echo "")
fi
VERSION="${VERSION:-1.2.0}"

DMG_PATH="${DMG_PATH:-$ROOT_DIR/build/TextGrab-${VERSION}.dmg}"
PROFILE="${NOTARYTOOL_PROFILE:-}"

if [[ ! -f "$DMG_PATH" ]]; then
  printf 'DMG not found: %s\nRun scripts/build-release.sh first.\n' "$DMG_PATH" >&2
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  printf 'Set NOTARYTOOL_PROFILE to a stored notarytool keychain profile.\n' >&2
  printf 'Create one with: xcrun notarytool store-credentials <profile>\n' >&2
  exit 1
fi

# Verify the exported app if it exists, otherwise verify the app in the DMG
APP_TO_VERIFY=""
if [[ -f "$ROOT_DIR/build/export/TextGrab.app/Contents/Info.plist" ]]; then
  APP_TO_VERIFY="$ROOT_DIR/build/export/TextGrab.app"
elif [[ -f "$ROOT_DIR/build/TextGrab.xcarchive/Products/Applications/TextGrab.app/Contents/Info.plist" ]]; then
  APP_TO_VERIFY="$ROOT_DIR/build/TextGrab.xcarchive/Products/Applications/TextGrab.app"
fi

if [[ -n "$APP_TO_VERIFY" ]]; then
  if ! codesign --verify --deep --strict "$APP_TO_VERIFY" 2>/dev/null; then
    printf 'The app is not signed or failed signature validation: %s\n' "$APP_TO_VERIFY" >&2
    exit 1
  fi
else
  printf 'WARNING: Could not locate app bundle for pre-notarization verification\n' >&2
fi

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# Final verification - fail if spctl assessment fails
if spctl --assess --type execute --verbose "$DMG_PATH" 2>/dev/null; then
  printf 'Notarized and stapled DMG verified: %s\n' "$DMG_PATH"
else
  printf 'ERROR: spctl assessment failed on notarized DMG\n' >&2
  exit 1
fi

printf 'Notarized and stapled DMG: %s\n' "$DMG_PATH"
