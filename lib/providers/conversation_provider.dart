import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/chat/view_models/conversation_view_model.dart';
import '../src/rust/model/local.dart' show LocalConversation;
import 'message_service_provider.dart';

/// 会话列表 Provider
final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  return ConversationListNotifier(ref);
});

/// 当前会话列表 Provider（便捷访问）
final conversationsProvider = Provider<List<LocalConversation>>((ref) {
  return ref.watch(conversationListProvider).conversations;
});

/// 指定会话 Provider（按 ID）
final conversationByIdProvider = Provider.family<LocalConversation?, String>((ref, id) {
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
  return ref.watch(
    messageServiceProvider.select((s) => s.totalUnreadCount),
  );
});
