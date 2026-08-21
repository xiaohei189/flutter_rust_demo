import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/chat/message_service_notifier.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/message.dart' show MessageType;
import '../mappers/message_display.dart';
import '../providers/message_provider.dart';
import '../providers/message_service_provider.dart';
import 'chat_detail_view_model.dart';

/// 聊天详情页多选模式：进入/退出、单选、全选与批量删除。
mixin ChatDetailSelectionMixin on FamilyNotifier<ChatDetailState, String> {
  MessageServiceNotifier get _messageService =>
      ref.read(messageServiceProvider.notifier);

  void enterSelectMode() {
    state = state.copyWith(selectMode: true, selectedMessages: const []);
  }

  void exitSelectMode() {
    state = state.copyWith(selectMode: false, selectedMessages: const []);
  }

  void toggleMessageSelection(ChatMessage message) {
    final selected = List<ChatMessage>.from(state.selectedMessages);
    if (selected.any((m) => m.clientMsgId == message.clientMsgId)) {
      selected.removeWhere((m) => m.clientMsgId == message.clientMsgId);
    } else {
      selected.add(message);
    }
    state = state.copyWith(selectedMessages: selected);
  }

  void toggleSelectAll() {
    final messages = ref
        .read(messagesByConversationProvider(arg))
        .where((m) => m.messageType != MessageType.system)
        .toList();
    if (messages.isEmpty) return;
    final allSelected = messages.every(
      (m) => state.selectedClientMsgIds.contains(m.clientMsgId),
    );
    state = state.copyWith(selectedMessages: allSelected ? const [] : messages);
  }

  Future<bool> deleteSelectedMessages() async {
    final messages = List<ChatMessage>.from(state.selectedMessages);
    if (messages.isEmpty) return false;
    try {
      for (final message in messages) {
        await _messageService.deleteMessage(
          conversationId: arg,
          clientMsgId: message.clientMsgId,
        );
      }
      exitSelectMode();
      return true;
    } catch (e) {
      state = state.copyWith(errorText: '删除选中消息失败: $e');
      return false;
    }
  }
}
