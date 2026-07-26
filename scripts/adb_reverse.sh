#!/bin/bash
# Android 模拟器端口转发脚本
# 将模拟器的端口转发到宿主机，使模拟器可以通过 127.0.0.1 访问宿主机服务
# 自动检测所有连接的设备/模拟器，对每个设备都设置端口转发

set -e

# 自动查找 adb 路径
ADB_CMD="adb"
if ! command -v adb &> /dev/null; then
    if [ -f "$HOME/Android/Sdk/platform-tools/adb" ]; then
        ADB_CMD="$HOME/Android/Sdk/platform-tools/adb"
    else
        echo "错误: 找不到 adb 命令，请确保 Android SDK 已安装或手动指定路径"
        exit 1
    fi
fi

echo "检测已连接的设备..."

# 获取所有已连接设备，存入数组
readarray -t DEVICE_ARRAY < <($ADB_CMD devices | tail -n +2 | grep -v "^$" | awk '{print $1}')

if [ ${#DEVICE_ARRAY[@]} -eq 0 ]; then
    echo "错误: 未检测到任何已连接的设备或模拟器"
    echo "请启动模拟器或连接设备后重试"
    exit 1
fi

echo "找到 ${#DEVICE_ARRAY[@]} 个设备/模拟器"
echo ""

# 需要转发的端口列表（格式: 端口号:说明）
PORTS=(
    "10001:WebSocket"
    "10002:OpenIM API"
    "10008:认证服务"
    "10005:MinIO"
)

# 遍历每个设备设置端口转发
for device in "${DEVICE_ARRAY[@]}"; do
    # 获取设备名称：优先 AVD 名称（模拟器），失败则用型号
    device_name=$($ADB_CMD -s "$device" emu avd name 2>/dev/null | head -1 | tr -d '\r\n' || true)
    if [ -z "$device_name" ] || [ "$device_name" = "OK" ]; then
        device_name=$($ADB_CMD -s "$device" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n' || true)
    fi
    [ -z "$device_name" ] && device_name="unknown"

    echo "📱 设备: $device ($device_name)"

    for port_info in "${PORTS[@]}"; do
        port="${port_info%%:*}"
        label="${port_info##*:}"

        if $ADB_CMD -s "$device" reverse tcp:"$port" tcp:"$port" 2>/dev/null; then
            echo "  ✓ $label ($port)"
        else
            echo "  ✗ $label ($port) - 失败"
        fi
    done
    echo ""
done

echo "端口转发设置完成！"
echo "所有 Android 设备/模拟器可通过 127.0.0.1 访问宿主机服务。"
