#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/SmartHomeConductor.xcodeproj"
SCHEME="SmartHomeConductor"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Conductor.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$ROOT_DIR/Config/ExportOptions-DeveloperID.plist"
MODE="${1:-unsigned}"
NOTARY_PROFILE="${CONDUCTOR_NOTARY_PROFILE:-CONDUCTOR_NOTARY}"

usage() {
  cat <<USAGE
Usage:
  ./Scripts/archive-mac.sh unsigned
  ./Scripts/archive-mac.sh signed
  ./Scripts/archive-mac.sh notarize

Modes:
  unsigned   Create an unsigned universal Catalyst archive for local inspection.
  signed     Create and export a Developer ID signed application.
  notarize   Create, export, submit, staple, and validate a signed application.

Environment:
  CONDUCTOR_NOTARY_PROFILE   notarytool Keychain profile (default: CONDUCTOR_NOTARY)
USAGE
}

case "$MODE" in
  unsigned | signed | notarize) ;;
  *)
    usage
    exit 2
    ;;
esac

mkdir -p "$BUILD_DIR"

archive_args=(
  archive
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration Release
  -destination "generic/platform=macOS,variant=Mac Catalyst"
  -archivePath "$ARCHIVE_PATH"
  ONLY_ACTIVE_ARCH=NO
)

if [[ "$MODE" == "unsigned" ]]; then
  archive_args+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${archive_args[@]}"

if [[ "$MODE" == "unsigned" ]]; then
  APP="$ARCHIVE_PATH/Products/Applications/SmartHomeConductor.app"
  test -d "$APP"
  lipo -archs "$APP/Contents/MacOS/SmartHomeConductor"
  echo "Unsigned archive created at $ARCHIVE_PATH"
  exit 0
fi

if ! security find-identity -v -p codesigning |
  rg -q "Developer ID Application"; then
  echo "No Developer ID Application identity is available in the login Keychain." >&2
  exit 3
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP="$EXPORT_PATH/SmartHomeConductor.app"
ZIP="$BUILD_DIR/SmartHomeConductor-mac.zip"

test -d "$APP"
lipo -archs "$APP/Contents/MacOS/SmartHomeConductor"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if [[ "$MODE" == "notarize" ]]; then
  xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

echo "Mac distribution package created at $ZIP"
