#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
SCRIPT_DIR="$PROJECT_ROOT/scripts"

APP_NAME="yapyap"
SCHEME="yapyap"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Generating Xcode project..."
xcodegen generate -q

echo "==> Building $APP_NAME (Release, arm64)..."
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -arch arm64 \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_ENTITLEMENTS="$SCRIPT_DIR/yapyap.entitlements" \
    clean build 2>&1 | (grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" || true) | tail -20

echo "==> Code signing..."
codesign --force --deep --sign "Apple Development: cnskyrin@gmail.com" \
    --entitlements "$SCRIPT_DIR/yapyap.entitlements" \
    "$APP_BUNDLE"

echo ""
echo "✅ Done!"
echo "   App:  $APP_BUNDLE"
echo ""
echo "Install: cp -R $APP_BUNDLE /Applications/"
