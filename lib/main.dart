import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/src/rust/frb_generated.dart';
import 'package:flutter_rust_demo/src/rust/api/simple.dart' show setLogDirectory;

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/host_config.dart';
import 'utils/login_storage.dart';
import 'services/im_client.dart';

/// WebSocket 地址；Android 模拟器内用 10.0.2.2 访问宿主机
String get kWsUrl => 'ws://${getHostAddress()}:10001';
/// HTTP API 基础地址；与 ws 同 host，Android 下不能用 localhost
String get kApiBaseUrl => 'http://${getHostAddress()}:10002';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Rust 库（bridge 必须先 init，才能调用 setLogDirectory）
  await RustLib.init();

  // 2. 设置 Rust 日志目录（方案2：由 Dart 传入可写目录，在首次 init_logger 前设置即可）
  final dir = await getTemporaryDirectory();
  setLogDirectory(path: dir.path);  

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
