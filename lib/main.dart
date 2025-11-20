import 'package:flutter/material.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';

import 'screens/main_screen.dart';
import 'services/message_service.dart';
import 'theme/app_theme.dart';

// 全局消息服务实例
final messageService = MessageService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  // 初始化并连接 WebSocket
  // TODO: 从登录接口获取真实的 userId 和 token
  try {
    await messageService.initialize(
      areaCode: '+86',
      phoneNumber: '17764008284',
      password: '284f3d09ea0695538e4ded1c1766d73a',
      platform: 5,
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
