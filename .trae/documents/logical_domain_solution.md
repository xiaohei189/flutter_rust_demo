# 逻辑域名方案实施计划

## 目标
使用统一的逻辑域名 `im.local` 替代硬编码的 IP 地址，所有端（Android 模拟器、Web、桌面）通过域名访问服务。

## 当前状态
- 代码中硬编码 IP 地址 `192.168.1.4`
- 使用 `config/dev.json` 配置文件（用户不认可此方案）
- 已尝试 dnsmasq 但遇到端口冲突问题

## 方案设计

### 1. 域名解析配置

#### 1.1 宿主机配置（Web、桌面端）
使用 `/etc/hosts` 文件添加域名解析：
```
192.168.1.4  im.local
```

优点：
- 简单直接，无需额外服务
- 立即生效，无需重启服务
- 所有本地应用都能解析

#### 1.2 Android 模拟器配置
Android 模拟器默认使用宿主机的 DNS，但需要确保 `systemd-resolved` 能正确解析。

方案：配置 `systemd-resolved` 使用本地 DNS 缓存
```bash
# 确保 systemd-resolved 启用
sudo systemctl enable systemd-resolved
sudo systemctl start systemd-resolved

# 配置使用本地 hosts 文件
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

验证：
```bash
# 宿主机验证
ping im.local
nslookup im.local

# Android 模拟器验证
adb shell ping im.local
```

### 2. 代码修改

#### 2.1 简化 host_config 文件
删除 `config/dev.json` 相关逻辑，直接使用域名：

**lib/utils/host_config_io.dart**
```dart
// 所有端统一使用逻辑域名
String getHostAddress() => 'im.local';
```

**lib/utils/host_config_stub.dart**
```dart
// Web 端使用逻辑域名
String getHostAddress() => 'im.local';
```

#### 2.2 删除配置文件
- 删除 `config/dev.json`
- 删除 `config/dev.json.example`
- 从 `.gitignore` 移除 `config/dev.json`

### 3. Docker 服务配置

更新 `openim-docker/.env`：
```env
MINIO_EXTERNAL_ADDRESS="http://im.local:10005"
```

重启服务使配置生效：
```bash
cd /home/weirui/workspace/openim-docker
docker compose down
docker compose up -d
```

### 4. 环境切换方案

当 IP 地址变更时（如更换网络环境），只需更新 `/etc/hosts`：

```bash
# 一键更新脚本
sudo sed -i 's/.*im.local/192.168.1.4  im.local/' /etc/hosts
```

或者手动编辑：
```bash
sudo vim /etc/hosts
```

### 5. 验证步骤

1. **宿主机验证**
   ```bash
   ping im.local
   curl http://im.local:10002
   curl http://im.local:10005
   ```

2. **Android 模拟器验证**
   ```bash
   adb shell ping im.local
   adb shell curl http://im.local:10002
   ```

3. **应用验证**
   - 启动 Flutter 应用
   - 登录测试
   - 发送图片测试

### 6. 故障排查

如果 Android 模拟器无法解析域名：

```bash
# 方法 1：重启模拟器 DNS
adb shell setprop net.dns1 127.0.0.53
adb shell setprop net.dns2 192.168.1.4

# 方法 2：使用 emulator 启动参数
emulator -avd <avd_name> -dns-server 192.168.1.4

# 方法 3：临时回退到 IP 地址（开发时）
# 修改 host_config_io.dart 返回 IP 而非域名
```

## 实施步骤

1. 配置 `/etc/hosts` 添加 `im.local` 解析
2. 确认 `systemd-resolved` 正常运行
3. 修改代码，删除配置文件相关逻辑
4. 更新 Docker 配置
5. 重启 Docker 服务
6. 验证所有端访问正常

## 优势

- **统一域名**：所有端使用相同的 `im.local`
- **无需配置文件**：不依赖 `config/dev.json`
- **易于切换**：只需修改 `/etc/hosts` 一处
- **标准方案**：使用系统标准的域名解析机制
