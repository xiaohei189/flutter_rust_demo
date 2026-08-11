import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/services.dart';
import '../domain/models/conversation.dart';
import '../ui/chat/providers/message_service_provider.dart';

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

// ==================== Conversation Providers ====================

/// 会话服务实例 Provider
final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService.instance;
});

/// 会话列表流 Provider
final conversationsStreamProvider = StreamProvider<List<Conversation>>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return service.conversationsStream;
});

/// 当前会话列表 Provider（从新服务）
final conversationsFromServiceProvider = Provider<List<Conversation>>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return service.conversations;
});

/// 会话同步状态流 Provider
final conversationSyncStatusStreamProvider =
    StreamProvider<ConversationSyncStatus>((ref) {
      final service = ref.watch(conversationServiceProvider);
      return service.syncStatusStream;
    });

/// 当前会话同步状态 Provider
final conversationSyncStatusProvider = Provider<ConversationSyncStatus>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return service.syncStatus;
});

/// 是否正在同步会话 Provider
final isSyncingConversationsProvider = Provider<bool>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return service.isSyncing;
});

/// 同步进度流 Provider
final syncProgressStreamProvider = StreamProvider<int>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return service.syncProgressStream;
});

/// 当前同步进度 Provider
final syncProgressProvider = Provider<int>((ref) {
  final service = ref.watch(conversationServiceProvider);
  return service.syncProgress;
});

// ==================== Message Providers ====================

/// 所有消息 Provider
final allMessagesProvider = Provider<Map<String, List<dynamic>>>((ref) {
  return ref.watch(messageServiceProvider).messages;
});

/// 指定会话的消息列表 Provider（Family）
final messagesProvider = Provider.family<List<dynamic>, String>((
  ref,
  conversationId,
) {
  return ref.watch(messageServiceProvider).messages[conversationId] ?? [];
});

// ==================== User Providers ====================

/// 用户服务实例 Provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserService.instance;
});

/// 当前登录用户资料流 Provider
final loginUserStreamProvider = StreamProvider<UserInfo?>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.loginUserStream;
});

/// 当前登录用户资料 Provider
final loginUserProvider = Provider<UserInfo?>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.loginUserProfile;
});

/// 用户资料缓存流 Provider
final userProfilesStreamProvider = StreamProvider<Map<String, UserInfo>>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.profilesStream;
});

/// 指定用户资料 Provider（Family）（从新服务）
final userProfileByIdProvider = Provider.family<UserInfo?, String>((
  ref,
  userId,
) {
  final service = ref.watch(userServiceProvider);
  return service.getUserProfile(userId);
});

// ==================== 当前选中会话 Provider ====================

/// 当前选中的会话 ID
final selectedConversationIdProvider = StateProvider<String?>((ref) => null);

/// 当前选中的会话
final selectedConversationProvider = Provider<Conversation?>((ref) {
  final conversationId = ref.watch(selectedConversationIdProvider);
  if (conversationId == null) return null;

  final service = ref.watch(conversationServiceProvider);
  return service.getConversation(conversationId);
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
