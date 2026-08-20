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
