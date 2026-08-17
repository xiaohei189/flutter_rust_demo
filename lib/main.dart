import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/generated/rust/frb_generated.dart';
import 'package:flutter_rust_demo/generated/rust/ffi/ffi_init.dart'
    show setLogDirectory;

import 'router/app_router.dart';
import 'ui/core/theme/app_theme.dart';
import 'data/config/host_config.dart';
import 'data/services/im_client.dart';
import 'data/services/app_lifecycle_service.dart';
import 'data/services/local_notification_service.dart';
import 'data/services/locale_service.dart';
import 'generated/rust/ffi/global.dart' show setAppBackgroundStatus;
import 'ui/core/widgets/app_lock_gate.dart';
import 'l10n/app_localizations.dart';

/// WebSocket 地址
String get kWsUrl => 'ws://${getHostAddress()}:10001';

/// HTTP API 基础地址
String get kApiBaseUrl => 'http://${getHostAddress()}:10002';

Future<void> main() async {
  // Flutter Driver 会创建自己的 Binding，必须在 WidgetsFlutterBinding 初始化前启用。
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }

  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Rust 库（bridge 必须先 init，才能调用 setLogDirectory）
  await RustLib.init();

  // 2. 设置 Rust 日志目录（输出到应用数据目录下的 logs 目录）
  final appDir = await getApplicationDocumentsDirectory();
  final logDir = '${appDir.path}/logs';
  await Directory(logDir).create(recursive: true);
  setLogDirectory(path: logDir);
  // initLogger 在 message_service_notifier.initialize() 中调用，避免重复初始化

  // 3. 保留本地凭证，下次启动时自动登录（splash_screen 会检查凭证有效性）

  // 4. 热重启时先关闭之前的 client，避免同 token 重复连接导致 TokenKickedError(1506)
  // 注意：热重启会重新初始化静态字段，旧的 ImClient.instance 已不可达
  // Rust SDK 的 connect() 会自动关闭已有连接，这里做兜底
  await ImClient.instance.close();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initServices() async {
    await LocaleService.instance.load();
    await LocalNotificationService.instance.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state != AppLifecycleState.resumed;
    // 状态未实际变化（如 inactive/hidden 反复触发）时不重复通知 SDK，避免重复触发同步
    if (!AppLifecycleService.instance.update(background: background)) return;
    try {
      unawaited(
        setAppBackgroundStatus(isBackground: background).catchError((_) {}),
      );
    } catch (_) {
      // SDK 未初始化时忽略前后台状态
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.createRouter(
      wsUrl: kWsUrl,
      apiBaseUrl: kApiBaseUrl,
    );

    return ProviderScope(
      child: ValueListenableBuilder<Locale?>(
        valueListenable: LocaleService.instance.locale,
        builder: (context, locale, _) => MaterialApp.router(
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appTitle ?? 'Flutter 聊天应用',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: AppLockGate(child: child ?? const SizedBox.shrink()),
          ),
          routerConfig: router,
        ),
      ),
    );
  }
}
