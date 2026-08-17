import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../data/services/services.dart';
import 'message_service_provider.dart';
import '../view_models/conversation_view_model.dart';

/// 会话服务实例 Provider
final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService();
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

/// 当前选中的会话 ID
final selectedConversationIdProvider = StateProvider<String?>((ref) => null);

/// 当前选中的会话
final selectedConversationProvider = Provider<Conversation?>((ref) {
  final conversationId = ref.watch(selectedConversationIdProvider);
  if (conversationId == null) return null;
  final service = ref.watch(conversationServiceProvider);
  return service.getConversation(conversationId);
});

/// 会话列表 Provider
final conversationListProvider =
    NotifierProvider<ConversationListNotifier, ConversationListState>(
      ConversationListNotifier.new,
    );

/// 当前会话列表 Provider（便捷访问）
final conversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationListProvider).conversations;
});

/// 会话列表单聊用户资料缓存，避免 itemBuilder 内逐项查询 Service。
final conversationUserProfilesProvider = Provider<Map<String, UserInfo>>((ref) {
  final conversations = ref.watch(conversationsProvider);
  final profiles = ref.watch(
    messageServiceProvider.select((s) => s.userProfiles),
  );
  final result = <String, UserInfo>{};
  for (final conversation in conversations) {
    if (conversation.conversationType == 1 && conversation.userId.isNotEmpty) {
      final profile = profiles[conversation.userId];
      if (profile != null) {
        result[conversation.userId] = profile;
      }
    }
  }
  return result;
});

/// 指定会话 Provider（按 ID）
final conversationByIdProvider = Provider.family<Conversation?, String>((
  ref,
  id,
) {
  final conversations = ref.watch(conversationsProvider);
  try {
    return conversations.firstWhere((c) => c.conversationId == id);
  } catch (_) {
    return null;
  }
});

/// 未读消息总数 Provider
/// 直接读取 Rust 侧 TotalUnreadCountChanged 事件推送的权威值，不从会话列表累加
final totalUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(messageServiceProvider.select((s) => s.totalUnreadCount));
});
