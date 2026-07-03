#!/bin/bash
# Android APK 安装脚本
# 列出可用设备，手动选择安装目标

set -e

# 自动查找 adb 路径
ADB_CMD="adb"
if ! command -v adb &> /dev/null; then
    if [ -f "$HOME/Android/Sdk/platform-tools/adb" ]; then
        ADB_CMD="$HOME/Android/Sdk/platform-tools/adb"
    else
        echo "错误: 找不到 adb 命令"
        exit 1
    fi
fi

# APK 路径：优先使用命令行参数，否则自动查找
APK_PATH="${1:-}"
if [ -z "$APK_PATH" ]; then
    APK_PATH=$(find build/app/outputs -name "app-debug.apk" -type f 2>/dev/null | head -1)
    if [ -z "$APK_PATH" ]; then
        APK_PATH=$(find build/app/outputs -name "*.apk" -type f 2>/dev/null | head -1)
    fi
fi

if [ -z "$APK_PATH" ] || [ ! -f "$APK_PATH" ]; then
    echo "错误: 找不到 APK 文件"
    echo "用法: $0 [apk路径]"
    exit 1
fi

echo "APK: $APK_PATH"
echo ""

# 获取所有已连接设备，存入数组
readarray -t DEVICE_ARRAY < <($ADB_CMD devices | tail -n +2 | grep -v "^$" | awk '{print $1}')

if [ ${#DEVICE_ARRAY[@]} -eq 0 ]; then
    echo "错误: 未检测到任何已连接的设备或模拟器"
    exit 1
fi

# 显示设备列表
echo "可用设备/模拟器:"
echo ""
for i in "${!DEVICE_ARRAY[@]}"; do
    device="${DEVICE_ARRAY[$i]}"
    # 优先用 AVD 名称（模拟器），失败则用型号
    device_name=$($ADB_CMD -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r\n' || true)
    if [ -z "$device_name" ] || [ "$device_name" = "OK" ]; then
        device_name=$($ADB_CMD -s "$device" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n' || true)
    fi
    [ -z "$device_name" ] && device_name="unknown"
    echo "  $((i + 1))) $device ($device_name)"
done

echo ""
echo -n "请选择要安装的设备编号 (1-${#DEVICE_ARRAY[@]}): "
read -r CHOICE || true

# 校验输入
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#DEVICE_ARRAY[@]}" ]; then
    echo "错误: 无效的选择"
    exit 1
fi

SELECTED="${DEVICE_ARRAY[$((CHOICE - 1))]}"
# 优先用 AVD 名称
device_name=$($ADB_CMD -s "$SELECTED" emu avd name 2>/dev/null | head -1 | tr -d '\r\n' || true)
if [ -z "$device_name" ] || [ "$device_name" = "OK" ]; then
    device_name=$($ADB_CMD -s "$SELECTED" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n' || true)
fi
[ -z "$device_name" ] && device_name="unknown"

echo ""
echo "正在安装到: $SELECTED ($device_name)..."

if $ADB_CMD -s "$SELECTED" install -r "$APK_PATH" 2>&1; then
    echo "✓ 安装成功"
else
    echo "✗ 安装失败"
    exit 1
fi
