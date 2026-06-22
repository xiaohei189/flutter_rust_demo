import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';
import 'package:flutter_rust_demo/src/rust/api/simple.dart'
    show setLogDirectory, initLogger, subscribeRustLogs;

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/host_config.dart';
import 'utils/login_storage.dart';
import 'services/im_client.dart';

/// WebSocket 地址
String get kWsUrl => 'ws://${getHostAddress()}:10001';

/// HTTP API 基础地址
String get kApiBaseUrl => 'http://${getHostAddress()}:10002';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Rust 库（bridge 必须先 init，才能调用 setLogDirectory）
  await RustLib.init();

  // 2. 设置 Rust 日志目录（输出到应用数据目录下的 logs 目录）
  final appDir = await getApplicationDocumentsDirectory();
  final logDir = '${appDir.path}/logs';
  await Directory(logDir).create(recursive: true);
  debugPrint('[Dart] 日志目录: $logDir');
  setLogDirectory(path: logDir);
  
  // 2.1 初始化日志系统（设置日志级别为 debug，输出到文件和控制台）
  try {
    await initLogger(logLevel: 'debug');
    debugPrint('[Dart] Rust 日志系统初始化成功');
    
    // 2.2 订阅 Rust 日志流，通过 Dart 的 print 输出到控制台
    subscribeRustLogs().listen((log) {
      // 使用 ANSI 颜色码美化输出
      String coloredLog;
      if (log.contains('[ERROR]')) {
        coloredLog = '\x1B[31m$log\x1B[0m'; // 红色
      } else if (log.contains('[WARN]')) {
        coloredLog = '\x1B[33m$log\x1B[0m'; // 黄色
      } else if (log.contains('[INFO]')) {
        coloredLog = '\x1B[32m$log\x1B[0m'; // 绿色
      } else if (log.contains('[DEBUG]')) {
        coloredLog = '\x1B[36m$log\x1B[0m'; // 青色
      } else if (log.contains('[TRACE]')) {
        coloredLog = '\x1B[90m$log\x1B[0m'; // 灰色
      } else {
        coloredLog = log;
      }
      print(coloredLog);
    });
  } catch (e) {
    debugPrint('[Dart] Rust 日志系统初始化失败: $e');
  }

  // 3. 每次启动清除本地凭证，不自动复用 token，要求重新输入账号密码登录
  await LoginStorage.clearCredentials();

  // 4. 热重启时先关闭之前的 client，避免同 token 重复连接导致 TokenKickedError(1506)
  await ImClient.instance.close();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(
      wsUrl: kWsUrl,
      apiBaseUrl: kApiBaseUrl,
    );

    return ProviderScope(
      child: MaterialApp.router(
        title: 'Flutter 聊天应用',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
