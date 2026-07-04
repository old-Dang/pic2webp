#!/usr/bin/env bash
# 打包 pic2webp.app 到 /Applications/
set -euo pipefail

APP_NAME="pic2webp"
BUNDLE_ID="com.danglei.pic2webp"
VERSION="${1:-1.0.0}"
BUILD=".build/arm64-apple-macosx/release"
STAGE="/tmp/${APP_NAME}_stage"
APP="/Applications/${APP_NAME}.app"

if [[ ! -f "${BUILD}/${APP_NAME}" ]]; then
    echo "❌ 找不到 ${BUILD}/${APP_NAME}，请先 swift build -c release"
    exit 1
fi

echo "🔨 打包 ${APP_NAME} v${VERSION}..."

rm -rf "$STAGE" "$APP"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"

cp "${BUILD}/${APP_NAME}" "${STAGE}/Contents/MacOS/${APP_NAME}"

cat > "${STAGE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>jpg</string>
                <string>jpeg</string>
                <string>png</string>
                <string>webp</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Image</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.image</string>
            </array>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST

printf "APPL????" > "${STAGE}/Contents/PkgInfo"

# Copy AppIcon.icns if it exists (for CFBundleIconFile)
SRC_DIR="$(cd "$(dirname "$0")/../Sources/Pic2WebP" && pwd)"
if [[ -f "$SRC_DIR/Assets.xcassets/AppIcon.appiconset/AppIcon.icns" ]]; then
    cp "$SRC_DIR/Assets.xcassets/AppIcon.appiconset/AppIcon.icns" "${STAGE}/Contents/Resources/AppIcon.icns"
    echo "📦 已复制 AppIcon.icns"
fi

# Copy resource files directly into Resources dir
if [[ -d "$SRC_DIR/Resources" ]]; then
    cp -R "$SRC_DIR/Resources/"* "${STAGE}/Contents/Resources/"
    echo "📦 已复制 Resources 目录"
fi

# Copy SwiftPM resource bundle if it exists (from build dir)
BUILD_BUNDLE="${BUILD}/pic2webp_pic2webp.bundle"
if [[ -d "$BUILD_BUNDLE" ]]; then
    cp -R "$BUILD_BUNDLE" "${STAGE}/Contents/Resources/"
    echo "📦 已复制资源包 pic2webp_pic2webp.bundle"
fi

cp -R "$STAGE" "$APP"
echo "✅ 已部署到 ${APP}"
ls -lh "${APP}/Contents/MacOS/${APP_NAME}"
ls -lh "${APP}/Contents/Resources/" 2>/dev/null
