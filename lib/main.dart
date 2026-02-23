import 'package:flutter/material.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';

import 'screens/splash_screen.dart';
import 'services/message_service.dart';
import 'theme/app_theme.dart';

// 全局消息服务实例
final messageService = MessageService();

/// WebSocket 地址，与 openim-flutter-demo 对齐时可改为配置
const kWsUrl = 'ws://localhost:10001';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Rust 库
  await RustLib.init();

  // 2. 热重启时先关闭之前的 client，避免同 token 重复连接导致 TokenKickedError(1506)
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
      home: const SplashScreen(wsUrl: kWsUrl),
    );
  }
}
