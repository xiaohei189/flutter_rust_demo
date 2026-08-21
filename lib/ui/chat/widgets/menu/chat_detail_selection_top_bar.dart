import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/message.dart' show MessageType;
import '../../mappers/message_display.dart';
import '../../providers/message_provider.dart';
import 'message_selection_bar.dart';

/// 聊天详情多选工具栏：按会话派生可选消息数量并渲染操作栏。
class ChatDetailSelectionTopBar extends ConsumerWidget {
  const ChatDetailSelectionTopBar({
    super.key,
    required this.conversationId,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClose,
    required this.onDelete,
    required this.onForwardOneByOne,
    required this.onMergeForward,
  });

  final String conversationId;
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onForwardOneByOne;
  final VoidCallback onMergeForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref
        .watch(messagesByConversationProvider(conversationId))
        .where((m) => m.messageType != MessageType.system)
        .toList();
    return MessageSelectionTopBar(
      count: selectedCount,
      totalCount: messages.length,
      onSelectAll: onSelectAll,
      onClose: onClose,
      onDelete: onDelete,
      onForwardOneByOne: onForwardOneByOne,
      onMergeForward: onMergeForward,
    );
  }
}
