#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DMG_PATH="${DMG_PATH:-$ROOT_DIR/build/TextGrab-1.0.0.dmg}"
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

if ! codesign --verify --deep --strict "$ROOT_DIR/build/export/TextGrab.app" 2>/dev/null; then
  printf 'The exported app is not signed or failed signature validation.\n' >&2
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

printf 'Notarized and stapled DMG: %s\n' "$DMG_PATH"
