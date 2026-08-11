import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/rust/model/message.dart' show MessageInfo;
import 'message_service_provider.dart';
import '../view_models/message_view_model.dart';

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

/// 消息列表 Provider（按会话 ID）
final messageListProvider =
    NotifierProvider.family<MessageListNotifier, MessageListState, String>(
      MessageListNotifier.new,
    );

/// 指定会话的消息列表 Provider（便捷访问）
final messagesByConversationIdProvider =
    Provider.family<List<MessageInfo>, String>((ref, conversationId) {
      return ref.watch(messageListProvider(conversationId)).messages;
    });
