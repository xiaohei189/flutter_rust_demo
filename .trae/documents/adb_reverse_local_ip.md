# 端口转发 + 本地 IP 方案

## 目标
所有端统一使用 `127.0.0.1` 访问服务，通过 `adb reverse` 端口转发让 Android 模拟器也能访问宿主机服务。不依赖环境 IP，换机器无需改配置。

## 当前状态
- `host_config_io.dart` 和 `host_config_stub.dart` 都读取 `config/dev.json`，默认回退到 `192.168.1.4`
- `getHostAddress()` 被 3 处引用：
  - `lib/main.dart:17` → `ws://${getHostAddress()}:10001` (WebSocket)
  - `lib/main.dart:20` → `http://${getHostAddress()}:10002` (API)
  - `lib/services/auth_api.dart:10` → `http://${getHostAddress()}:10008` (Auth)
- MinIO `EXTERNAL_ADDRESS` 当前为 `http://im.local:10005`

## 方案

### 各端访问方式
| 端 | 地址 | 方式 |
|----|------|------|
| Web | `127.0.0.1:port` | 直接访问宿主机 |
| 桌面 | `127.0.0.1:port` | 直接访问宿主机 |
| Android 模拟器 | `127.0.0.1:port` | `adb reverse` 转发到宿主机 |

### 端口转发命令
```bash
adb reverse tcp:10001 tcp:10001  # WebSocket
adb reverse tcp:10002 tcp:10002  # OpenIM API
adb reverse tcp:10008 tcp:10008  # Auth 认证
```

## 修改步骤

### 1. 简化 host_config 文件
- `host_config_io.dart` — 删除 config/dev.json 读取逻辑，直接返回 `'127.0.0.1'`
- `host_config_stub.dart` — 直接返回 `'127.0.0.1'`
- 删除 `dart:convert` 和 `dart:io` 的 import（不再需要）

### 2. 删除配置文件
- 删除 `config/dev.json`
- 删除 `config/dev.json.example`
- 从 `.gitignore` 移除 `config/dev.json` 条目

### 3. 创建端口转发脚本
- 创建 `scripts/adb_reverse.sh`，自动设置所有端口转发
- 内容：
```bash
#!/bin/bash
adb reverse tcp:10001 tcp:10001
adb reverse tcp:10002 tcp:10002
adb reverse tcp:10008 tcp:10008
echo "端口转发已设置"
```

### 4. 更新 MinIO 外部地址
- `openim-docker/.env` 第 49 行：`MINIO_EXTERNAL_ADDRESS="http://127.0.0.1:10005"`
- 注意：MinIO 图片 URL 由服务端返回，其他端（如真机）需要能访问该地址。开发环境所有端都在同一台机器上，通过端口转发可以访问。

### 5. 更新 main.dart 注释
- 移除过时的 Android 模拟器注释

## 验证
1. 运行 `scripts/adb_reverse.sh` 设置端口转发
2. `flutter run` 启动应用
3. 在 Android 模拟器中登录测试
4. 在 Web 端登录测试
