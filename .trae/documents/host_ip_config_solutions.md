# 开发环境 IP 配置方案对比

## 当前方案（配置文件）
使用 `config/dev.json` 存储 IP 地址，代码读取配置文件。

**优点：**
- 灵活，可以自定义任意 IP
- 配置与代码分离

**缺点：**
- 需要手动创建和修改配置文件
- 换环境需要重新配置
- 新开发者需要复制模板文件

---

## 替代方案

### 方案 1：编译时注入（推荐）
使用 Flutter 的 `--dart-define` 在编译时注入 IP 常量。

**使用方式：**
```bash
# 编译时指定 IP
flutter run --dart-define=HOST_IP=192.168.1.4

# 或创建快捷脚本
alias flutter-run='flutter run --dart-define=HOST_IP=$(hostname -I | awk "{print \$1}")'
```

**代码实现：**
```dart
String getHostAddress() {
  return const String.fromEnvironment('HOST_IP', defaultValue: '192.168.1.4');
}
```

**优点：**
- 不需要配置文件
- 编译时确定，性能好
- 可以通过脚本自动化

**缺点：**
- 每次换 IP 需要重新编译（但开发时本来就需要编译）
- 需要记住命令行参数或配置 alias

---

### 方案 2：运行时自动检测（最自动化）
应用启动时自动检测宿主机 IP。

**实现思路：**
```dart
import 'dart:io';

Future<String> getHostAddress() async {
  // 获取本机所有网络接口
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      // 过滤出 IPv4 地址，排除回环地址
      if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
        // 优先返回 192.168.x.x 或 10.x.x.x 等内网地址
        if (addr.address.startsWith('192.168.') || 
            addr.address.startsWith('10.') ||
            addr.address.startsWith('172.')) {
          return addr.address;
        }
      }
    }
  }
  return '192.168.1.4'; // 默认值
}
```

**优点：**
- 完全自动化，零配置
- 换环境自动适应
- 不需要任何配置文件或脚本

**缺点：**
- 多网卡环境可能选错 IP
- 需要异步获取（但可以在 main 中提前获取）
- 某些特殊网络环境可能检测不到

---

### 方案 3：环境变量（系统级）
使用系统环境变量存储 IP。

**使用方式：**
```bash
# 设置环境变量（在 .bashrc 或 .zshrc 中）
export FLUTTER_HOST_IP=192.168.1.4

# 或在启动脚本中
FLUTTER_HOST_IP=192.168.1.4 flutter run
```

**代码实现：**
```dart
import 'dart:io';

String getHostAddress() {
  return Platform.environment['FLUTTER_HOST_IP'] ?? '192.168.1.4';
}
```

**优点：**
- 不需要配置文件
- 可以全局设置一次

**缺点：**
- 需要配置系统环境变量
- 不同开发者需要配置自己的环境
- 不如配置文件直观

---

### 方案 4：Docker 网络自动配置
利用 Docker 网络特性，自动配置固定 IP。

**实现思路：**
- 在 `docker-compose.yml` 中为服务配置固定 IP
- 所有端通过固定 IP 访问

**优点：**
- 自动化
- 不需要修改代码

**缺点：**
- 依赖 Docker 网络配置
- 不同机器可能需要调整 Docker 配置
- 不够灵活

---

## 推荐方案

**方案 1（编译时注入）** 最适合当前项目：
1. 不需要额外的配置文件
2. 代码简洁
3. 可以通过 alias 或脚本自动化
4. 编译时确定，性能好
5. 换环境只需重新编译（开发时本来就需要）

**方案 2（运行时检测）** 作为备选：
- 如果追求完全自动化
- 但需要处理多网卡等边界情况

---

## 待确认

请确认您倾向于哪种方案：
1. 编译时注入（`--dart-define`）
2. 运行时自动检测
3. 环境变量
4. 其他想法？
