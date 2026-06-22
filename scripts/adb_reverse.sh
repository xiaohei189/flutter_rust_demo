#!/bin/bash
# Android 模拟器端口转发脚本
# 将模拟器的端口转发到宿主机，使模拟器可以通过 127.0.0.1 访问宿主机服务

set -e

# 自动查找 adb 路径
ADB_CMD="adb"
if ! command -v adb &> /dev/null; then
    # 尝试常见的 Android SDK 路径
    if [ -f "$HOME/Android/Sdk/platform-tools/adb" ]; then
        ADB_CMD="$HOME/Android/Sdk/platform-tools/adb"
    else
        echo "错误: 找不到 adb 命令，请确保 Android SDK 已安装或手动指定路径"
        exit 1
    fi
fi

echo "设置 Android 模拟器端口转发..."

# 转发 WebSocket 端口
$ADB_CMD reverse tcp:10001 tcp:10001
echo "✓ WebSocket (10001)"

# 转发 OpenIM API 端口
$ADB_CMD reverse tcp:10002 tcp:10002
echo "✓ OpenIM API (10002)"

# 转发认证服务端口
$ADB_CMD reverse tcp:10008 tcp:10008
echo "✓ 认证服务 (10008)"

# 转发 MinIO 端口
$ADB_CMD reverse tcp:10005 tcp:10005
echo "✓ MinIO (10005)"

echo ""
echo "端口转发设置完成！"
echo "现在 Android 模拟器可以通过 127.0.0.1 访问宿主机服务。"
