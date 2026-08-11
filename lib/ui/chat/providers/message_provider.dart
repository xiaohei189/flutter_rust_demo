import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/rust/model/message.dart' show MessageInfo;
import '../view_models/message_view_model.dart';

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
