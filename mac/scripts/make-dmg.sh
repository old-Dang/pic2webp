#!/usr/bin/env bash
# 用 create-dmg 打包 pic2webp.dmg
set -euo pipefail

APP_NAME="pic2webp"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}"
APP="/Applications/${APP_NAME}.app"
STAGE="/tmp/${DMG_NAME}_dmg"
DMG_OUT="dist/${DMG_NAME}.dmg"

if [[ ! -d "$APP" ]]; then
    echo "❌ 找不到 $APP，请先 ./scripts/make-app.sh"
    exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "⚠️  未装 create-dmg，正在 brew install..."
    brew install create-dmg
fi

echo "📀 打包 ${DMG_NAME}..."

rm -rf "$STAGE" "$DMG_OUT"
mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"

create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 175 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_OUT" \
    "$STAGE" || true

if [[ ! -f "$DMG_OUT" ]]; then
    echo "⚠️  create-dmg 失败，尝试 hdiutil 简单打包..."
    rm -f "$DMG_OUT"
    hdiutil create -volname "${APP_NAME}" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT"
fi

echo "✅ DMG 已生成: $DMG_OUT"
ls -lh "$DMG_OUT"
