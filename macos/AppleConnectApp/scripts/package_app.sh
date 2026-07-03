#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/Config"
BUILD_DIR="$ROOT_DIR/Build"
APP_NAME="Fact"
TARGET_NAME="AppleConnectApp"
RESOURCE_BUNDLE="${TARGET_NAME}_${TARGET_NAME}.bundle"
ICON_NAME="fact"
ICON_DIR="$ROOT_DIR/Sources/AppleConnectApp/Resources/$ICON_NAME.icon"

cd "$ROOT_DIR"

swift build

PRODUCT_DIR="$(swift build --show-bin-path)"
EXECUTABLE="$PRODUCT_DIR/$TARGET_NAME"
RESOURCE_DIR="$PRODUCT_DIR/$RESOURCE_BUNDLE"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
APP_RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$APP_RESOURCES_DIR"

cp "$CONFIG_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

set_plist_string() {
  local key="$1"
  local value="$2"
  /usr/libexec/PlistBuddy -c "Set :$key $value" "$CONTENTS_DIR/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :$key string $value" "$CONTENTS_DIR/Info.plist"
}

if [[ -d "$RESOURCE_DIR" ]]; then
  cp -R "$RESOURCE_DIR" "$APP_DIR/$RESOURCE_BUNDLE"
  cp -R "$RESOURCE_DIR" "$APP_RESOURCES_DIR/$RESOURCE_BUNDLE"
fi

if [[ -d "$ICON_DIR" ]]; then
  xcrun actool "$ICON_DIR" \
    --compile "$APP_RESOURCES_DIR" \
    --output-format human-readable-text \
    --notices \
    --warnings \
    --output-partial-info-plist "$BUILD_DIR/assetcatalog_generated_info.plist" \
    --app-icon "$ICON_NAME" \
    --enable-on-demand-resources NO \
    --development-region en \
    --target-device mac \
    --minimum-deployment-target 26.0 \
    --platform macosx \
    --bundle-identifier com.infinity.factory.mac

  set_plist_string CFBundleIconFile "$ICON_NAME"
  set_plist_string CFBundleIconName "$ICON_NAME"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

echo "Created $APP_DIR"
echo "Bundle identifier: com.infinity.factory.mac"
