import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart';
import 'package:flutter_rust_demo/src/rust/api/simple.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';

import 'screens/splash_screen.dart';
import 'services/message_service.dart';
import 'theme/app_theme.dart';
import 'utils/host_config.dart';

// 全局消息服务实例
final messageService = MessageService();

/// WebSocket 地址；Android 模拟器内用 10.0.2.2 访问宿主机
String get kWsUrl => 'ws://${getHostAddress()}:10001';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Rust 库（bridge 必须先 init，才能调用 setLogDirectory）
  await RustLib.init();

  // 2. 设置 Rust 日志目录（方案2：由 Dart 传入可写目录，在首次 init_logger 前设置即可）
  final dir = await getTemporaryDirectory();
  setLogDirectory(path: dir.path);

  // 3. 热重启时先关闭之前的 client，避免同 token 重复连接导致 TokenKickedError(1506)
  await closeCurrentClientIfAny();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 聊天应用',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(wsUrl: kWsUrl),
    );
  }
}
