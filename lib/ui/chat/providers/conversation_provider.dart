import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../generated/rust/model/user.dart' show UserInfo;
import 'message_service_provider.dart';
import '../view_models/conversation_view_model.dart';

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
