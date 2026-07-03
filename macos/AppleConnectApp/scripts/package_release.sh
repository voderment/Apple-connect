#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
APP_NAME="Fact"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

"$ROOT_DIR/scripts/package_app.sh"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "Signing $APP_DIR"
  codesign \
    --force \
    --deep \
    --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_DIR"
else
  echo "Skipping codesign: DEVELOPER_ID_APPLICATION is not set"
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
echo "Created $ZIP_PATH"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "Submitting $ZIP_PATH for notarization"
  xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

  echo "Stapling notarization ticket"
  xcrun stapler staple "$APP_DIR"

  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
  echo "Created notarized $ZIP_PATH"
else
  echo "Skipping notarization: APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD are not all set"
fi
