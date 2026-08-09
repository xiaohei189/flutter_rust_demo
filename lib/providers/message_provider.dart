import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/model/message.dart' show MessageInfo;
import '../ui/chat/view_models/message_view_model.dart';
import 'message_service_provider.dart';

/// 消息列表 Provider（按会话 ID）
final messageListProvider =
    StateNotifierProvider.family<MessageListNotifier, MessageListState, String>(
      (ref, conversationId) {
        return MessageListNotifier(
          ref.read(messageServiceProvider.notifier),
          conversationId,
        );
      },
    );

/// 指定会话的消息列表 Provider（便捷访问）
final messagesByConversationIdProvider =
    Provider.family<List<MessageInfo>, String>((ref, conversationId) {
      return ref.watch(messageListProvider(conversationId)).messages;
    });
