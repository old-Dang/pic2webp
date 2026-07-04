#!/bin/bash
# Pic2WebP - 修复 Gatekeeper 权限问题
# 如果打开 Pic2WebP 时提示"已损坏，无法打开。 你应该将它移到废纸篓。"
# 请双击运行此脚本

echo "=============================================="
echo "  Pic2WebP - Gatekeeper 权限修复工具"
echo "=============================================="
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/Pic2WebP.app"

# 如果还在 DMG 挂载卷里（/Volumes/xxx），提醒用户先拖到 Applications
if [[ "$SCRIPT_DIR" == /Volumes/* ]]; then
    echo "⚠️  请先把 Pic2WebP.app 拖到「应用程序」文件夹"
    echo ""
    echo "   然后打开终端，运行："
    echo "   sudo xattr -rd com.apple.quarantine /Applications/Pic2WebP.app"
    echo ""
    echo "按回车键退出..."
    read
    exit 0
fi

# 当前目录没有 .app 则检查 /Applications
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="/Applications/Pic2WebP.app"
    if [ ! -d "$APP_PATH" ]; then
        echo "❌ 找不到 Pic2WebP.app"
        echo "   请确认已将 Pic2WebP.app 放入「应用程序」文件夹"
        echo ""
        echo "按回车键退出..."
        read
        exit 1
    fi
fi

echo "📁 目标: $APP_PATH"
echo ""

# 先尝试不需要 sudo 的方式
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ 修复成功！现在可以正常打开 Pic2WebP 了"
else
    echo "🔑 需要管理员权限，请输入密码（输入时屏幕不显示字符是正常的）："
    sudo xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ 修复成功！现在可以正常打开 Pic2WebP 了"
    else
        echo ""
        echo "❌ 修复失败，请手动在终端执行："
        echo "   sudo xattr -rd com.apple.quarantine /Applications/Pic2WebP.app"
    fi
fi

echo ""
echo "按回车键退出..."
read
