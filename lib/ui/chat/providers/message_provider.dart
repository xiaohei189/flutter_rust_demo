import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/chat_message.dart' show ChatMessage;
import 'message_service_provider.dart';
import '../view_models/message_view_model.dart';

/// 所有消息 Provider
final allMessagesProvider = Provider<Map<String, List<ChatMessage>>>((ref) {
  return ref.watch(messageServiceProvider).messages;
});

/// 指定会话的消息列表 Provider（Family）
final messagesProvider = Provider.family<List<ChatMessage>, String>((
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
    Provider.family<List<ChatMessage>, String>((ref, conversationId) {
      return ref.watch(messageListProvider(conversationId)).messages;
    });
