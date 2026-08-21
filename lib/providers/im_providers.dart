import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/services.dart';

// ==================== ImClient Provider ====================

/// ImClient 实例 Provider
final imClientProvider = Provider<ImClient>((ref) {
  return ImClient.instance;
});

// ==================== Connection Providers ====================

/// 连接服务实例 Provider
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  return ConnectionService.instance;
});

/// 导航服务 Provider（基础设施）
final navigationServiceProvider = Provider<NavigationService>((ref) {
  return NavigationService.instance;
});

/// 媒体上传服务 Provider
final mediaUploadServiceProvider = Provider<MediaUploadService>((ref) {
  return const MediaUploadServiceImpl();
});

// ==================== 基础设施 DI 桥 ====================
// 单例只在此基础设施层暴露；业务/UI 一律通过 Provider 访问。

/// 应用生命周期服务 Provider（基础设施）
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService.instance;
});

/// 本地通知服务 Provider（基础设施）
final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService.instance,
);

/// 语言服务 Provider（基础设施）
final localeServiceProvider = Provider<LocaleService>((ref) {
  return LocaleService.instance;
});

/// 文件打开服务 Provider（基础设施）
final fileOpenServiceProvider = Provider<FileOpenService>((ref) {
  return FileOpenService.instance;
});

/// 应用锁服务 Provider（基础设施）
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService.instance;
});

/// 当前连接状态 Provider
final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final service = ref.watch(connectionServiceProvider);
  return service.status;
});

/// 是否已连接 Provider（从新服务）
final isConnectedFromServiceProvider = Provider<bool>((ref) {
  final service = ref.watch(connectionServiceProvider);
  return service.isConnected;
});
