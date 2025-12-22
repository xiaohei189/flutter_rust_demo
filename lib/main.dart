import 'package:flutter/material.dart';
import 'package:flutter_rust_demo/src/rust/api/logger.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';

import 'screens/main_screen.dart';
import 'services/message_service.dart';
import 'theme/app_theme.dart';

// 全局消息服务实例
final messageService = MessageService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 初始化 Rust 库
  await RustLib.init();

  // 2. 初始化日志系统（必须在其他逻辑之前）
  try {
    initLoggerSimple(logLevel: 'info,rust_lib_flutter_rust_demo=debug');
    debugPrint('✅ 日志系统初始化成功');
  } catch (e) {
    debugPrint('⚠️ 日志系统初始化失败: $e');
    // 即使日志初始化失败也继续运行
  }

  // 3. 初始化并连接 WebSocket（登录已集成在 SDK 中）
  try {
    await messageService.initialize(
      wsUrl: 'ws://localhost:10001', // WebSocket 地址
    );
  } catch (e) {
    debugPrint('初始化 WebSocket 连接失败: $e');
    // 即使连接失败也继续运行应用
  }

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
      home: const MainScreen(),
    );
  }
}
