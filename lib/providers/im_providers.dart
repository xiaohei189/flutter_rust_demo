import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/services.dart';
import '../ui/chat/providers/conversation_provider.dart';

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

/// 连接状态流 Provider
final connectionStatusStreamProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectionServiceProvider);
  return service.statusStream;
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

// ==================== 组合状态 Providers ====================

/// IM 初始化状态（组合了连接、会话同步等状态）
final imInitStateProvider = Provider<Map<String, dynamic>>((ref) {
  final isConnected = ref.watch(isConnectedFromServiceProvider);
  final syncStatus = ref.watch(conversationSyncStatusProvider);
  final syncProgress = ref.watch(syncProgressProvider);

  return {
    'isConnected': isConnected,
    'syncStatus': syncStatus,
    'syncProgress': syncProgress,
    'isReady': isConnected && syncStatus == ConversationSyncStatus.completed,
  };
});
