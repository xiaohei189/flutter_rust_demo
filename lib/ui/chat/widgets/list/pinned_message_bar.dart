import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/message_extras.dart' show MessageExtras;
import '../../../core/theme/app_theme.dart';
import '../../mappers/message_display.dart';
import '../../providers/message_extras_provider.dart';
import '../../providers/message_provider.dart';

/// 会话顶部「置顶消息」条：展示最近一条置顶消息，点击定位、右侧取消置顶。
///
/// 没有置顶消息（或置顶的消息已经不在当前加载范围内）时自动隐藏。
class PinnedMessageBar extends ConsumerWidget {
  const PinnedMessageBar({
    super.key,
    required this.conversationId,
    required this.onTapMessage,
  });

  final String conversationId;
  final void Function(String clientMsgId) onTapMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(messageExtrasProvider);
    final messages = ref.watch(messagesByConversationProvider(conversationId));
    final pinned = _latestPinnedMessage(extras, messages);
    if (pinned == null) return const SizedBox.shrink();

    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted,
      child: InkWell(
        onTap: () => onTapMessage(pinned.clientMsgId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Icon(Icons.push_pin_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _previewOf(pinned),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: '取消置顶',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(messageExtrasProvider.notifier)
                    .setPinned(conversationId, pinned.clientMsgId, false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 最近的置顶消息；置顶的消息不在当前列表里（历史分页之外）时返回 null。
  ChatMessage? _latestPinnedMessage(
    Map<String, MessageExtras> extras,
    List<ChatMessage> messages,
  ) {
    var latestPinnedAt = -1;
    String? latestId;
    final prefix = '$conversationId|';
    for (final entry in extras.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final pinned = entry.value.pinned;
      if (!pinned) continue;
      final pinnedAt = entry.value.pinnedAt;
      if (pinnedAt <= latestPinnedAt) continue;
      latestPinnedAt = pinnedAt;
      latestId = entry.key.substring(prefix.length);
    }
    if (latestId == null) return null;
    for (final message in messages.reversed) {
      if (message.clientMsgId == latestId) return message;
    }
    return null;
  }

  String _previewOf(ChatMessage message) {
    final text = message.displayText.trim();
    if (text.isEmpty) return '[消息]';
    return text.replaceAll('\n', ' ');
  }
}
