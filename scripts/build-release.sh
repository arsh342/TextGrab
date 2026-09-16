#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/TextGrab.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/export}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/build/TextGrab-1.0.0.dmg}"
SCHEME="${SCHEME:-TextGrab}"

mkdir -p "$(dirname "$ARCHIVE_PATH")"

SIGNING_ARGS=("CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED:-YES}")
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  SIGNING_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  SIGNING_ARGS+=("CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")
elif [[ -z "${DEVELOPMENT_TEAM:-}" && "${CODE_SIGNING_ALLOWED:-YES}" == "YES" ]]; then
  SIGNING_ARGS+=("CODE_SIGN_IDENTITY=-")
fi

xcodebuild archive \
  -project TextGrab.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${SIGNING_ARGS[@]}"

if [[ -n "${EXPORT_OPTIONS_PLIST:-}" ]]; then
  rm -rf "$EXPORT_PATH"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  printf 'Exported app to %s\n' "$EXPORT_PATH"
else
  printf 'Created archive at %s\n' "$ARCHIVE_PATH"
  printf 'Set EXPORT_OPTIONS_PLIST to export a signed app or notarization-ready package.\n'
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/TextGrab.app"
if [[ -f "$EXPORT_PATH/TextGrab.app/Contents/Info.plist" ]]; then
  APP_PATH="$EXPORT_PATH/TextGrab.app"
fi

DMG_STAGING="${TMPDIR:-/tmp}/textgrab-dmg-staging"
DMG_MOUNT="/Volumes/TextGrab"
RW_DMG_PATH="${DMG_PATH%.dmg}.rw.dmg"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto "$APP_PATH" "$DMG_STAGING/TextGrab.app"
ln -s /Applications "$DMG_STAGING/Applications"
mkdir -p "$DMG_STAGING/.background"
sips -z 440 720 "$ROOT_DIR/resources/dmg-background.png" \
  --out "$DMG_STAGING/.background/dmg-background.png" >/dev/null
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create \
  -size 20m \
  -fs HFS+ \
  -volname "TextGrab" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH" >/dev/null

hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 || true
hdiutil attach "$RW_DMG_PATH" -nobrowse -noautoopen >/dev/null

cleanup_mount() {
  hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "TextGrab"
    open
    delay 1
    set theWindow to container window
    set current view of theWindow to icon view
    set toolbar visible of theWindow to false
    set statusbar visible of theWindow to false
    set bounds of theWindow to {200, 160, 920, 600}
    set viewOptions to icon view options of theWindow
    set icon size of viewOptions to 112
    set text size of viewOptions to 14
    set arrangement of viewOptions to not arranged
    set background picture of viewOptions to POSIX file "$DMG_MOUNT/.background/dmg-background.png"
    set position of item "TextGrab.app" to {198, 260}
    set position of item "Applications" to {522, 260}
    close
    open
    update without registering applications
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DMG_MOUNT" >/dev/null
trap - EXIT
hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -ov \
  -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG_PATH"
rm -rf "$DMG_STAGING"

hdiutil verify "$DMG_PATH" >/dev/null
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
  printf 'Code signature verified for %s\n' "$APP_PATH"
else
  printf 'App is unsigned; use CODE_SIGNING_ALLOWED=YES with a Developer ID identity before distribution.\n'
fi
printf 'Created DMG at %s\n' "$DMG_PATH"
