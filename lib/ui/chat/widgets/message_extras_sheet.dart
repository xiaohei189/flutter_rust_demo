import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../mappers/message_display.dart';
import '../providers/message_extras_provider.dart';
import '../providers/message_provider.dart';

/// 消息本地扩展列表的两种视角：标记（收藏）/ 置顶。
enum MessageExtrasKind { flagged, pinned }

/// 会话内消息扩展列表（底部弹层）。
///
/// 数据来自本地扩展（`MessageExtras`）：只列当前已加载的消息，
/// 更早历史里的条目会提示「加载更多」逐页取回。
class MessageExtrasSheet extends ConsumerStatefulWidget {
  const MessageExtrasSheet({
    super.key,
    required this.kind,
    required this.conversationId,
    this.onMessageTap,
  });

  final MessageExtrasKind kind;
  final String conversationId;
  final ValueChanged<String>? onMessageTap;

  @override
  ConsumerState<MessageExtrasSheet> createState() => _MessageExtrasSheetState();
}

class _MessageExtrasSheetState extends ConsumerState<MessageExtrasSheet> {
  bool _loadingMore = false;

  bool get _isPinned => widget.kind == MessageExtrasKind.pinned;

  String get _title => _isPinned ? '置顶消息' : '标记消息';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // 订阅整表（条目很少）以在标记/置顶变化时刷新；具体查询用 read。
    ref.watch(messageExtrasProvider);
    final extras = ref.read(messageExtrasProvider.notifier);
    final messages = ref.watch(
      messagesByConversationProvider(widget.conversationId),
    );

    // 置顶按置顶时间从新到旧；标记按会话内消息顺序从新到旧。
    final List<String> ids;
    final List<ChatMessage> items;
    if (_isPinned) {
      ids = extras.pinnedMessageIds(widget.conversationId);
      final byId = {
        for (final message in messages) message.clientMsgId: message,
      };
      items = [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    } else {
      final flaggedIds = extras.flaggedMessageIds(widget.conversationId);
      ids = flaggedIds.toList();
      items = [
        for (final message in messages.reversed)
          if (flaggedIds.contains(message.clientMsgId)) message,
      ];
    }
    final loadedIds = {for (final message in items) message.clientMsgId};
    final missingCount = ids.where((id) => !loadedIds.contains(id)).length;

    // 自带 Material：弹层在 App 里由 showModalBottomSheet 提供 Material，
    // 但组件独立可测/可复用时不该依赖这一点。
    return Material(
      color: colors.surface,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ids.isNotEmpty)
                    Text(
                      '${ids.length} 条',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider.withValues(alpha: 0.6)),
            Expanded(child: _buildBody(items, missingCount)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ChatMessage> items, int missingCount) {
    final colors = context.appColors;
    if (items.isEmpty && missingCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPinned ? Icons.push_pin_outlined : Icons.flag_outlined,
              size: 48,
              color: colors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _isPinned ? '还没有置顶的消息' : '还没有标记的消息',
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _isPinned ? '长按消息选择「置顶消息」即可置顶' : '长按消息选择「标记」即可收藏',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length + (missingCount > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _buildLoadMore(missingCount);
        }
        return _buildRow(items[index]);
      },
    );
  }

  Widget _buildRow(ChatMessage message) {
    final colors = context.appColors;
    final senderName = message.senderNickname.isNotEmpty
        ? message.senderNickname
        : message.sendId;
    return ListTile(
      leading: UserAvatar.fromUser(
        user: User(
          id: message.sendId,
          name: senderName,
          avatar: message.senderFaceUrl.isNotEmpty
              ? message.senderFaceUrl
              : null,
        ),
        radius: 18,
      ),
      title: Text(
        _previewOf(message),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, color: colors.textPrimary),
      ),
      subtitle: Text(
        '$senderName  ${formatMessageTime(message.sendDateTime)}',
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
      ),
      trailing: IconButton(
        icon: Icon(_isPinned ? Icons.push_pin : Icons.flag, size: 18),
        tooltip: _isPinned ? '取消置顶' : '取消标记',
        onPressed: () {
          final notifier = ref.read(messageExtrasProvider.notifier);
          if (_isPinned) {
            notifier.setPinned(
              widget.conversationId,
              message.clientMsgId,
              false,
            );
          } else {
            notifier.toggleFlagged(widget.conversationId, message.clientMsgId);
          }
        },
      ),
      onTap: () {
        Navigator.of(context).pop();
        widget.onMessageTap?.call(message.clientMsgId);
      },
    );
  }

  /// 更早历史里还有条目：给一个「加载更多」出口，逐页取回。
  Widget _buildLoadMore(int missingCount) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '还有 $missingCount 条更早的${_isPinned ? '置顶' : '标记'}消息',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ),
          if (_loadingMore)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(onPressed: _loadMore, child: const Text('加载更多')),
        ],
      ),
    );
  }

  Future<void> _loadMore() async {
    final messages = ref.read(
      messagesByConversationProvider(widget.conversationId),
    );
    if (messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      await ref
          .read(messageListProvider(widget.conversationId).notifier)
          .loadHistoryMessages(
            count: 20,
            startClientMsgId: messages.first.clientMsgId,
          );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _previewOf(ChatMessage message) {
    final text = message.displayText.trim();
    if (text.isEmpty) return '[消息]';
    return text.replaceAll('\n', ' ');
  }
}

/// 会话内「标记消息」列表（底部弹层）。
class MarkedMessagesSheet extends StatelessWidget {
  const MarkedMessagesSheet({
    super.key,
    required this.conversationId,
    this.onMessageTap,
  });

  final String conversationId;
  final ValueChanged<String>? onMessageTap;

  @override
  Widget build(BuildContext context) {
    return MessageExtrasSheet(
      kind: MessageExtrasKind.flagged,
      conversationId: conversationId,
      onMessageTap: onMessageTap,
    );
  }
}

/// 会话内「置顶消息」列表（底部弹层）。
class PinnedMessagesSheet extends StatelessWidget {
  const PinnedMessagesSheet({
    super.key,
    required this.conversationId,
    this.onMessageTap,
  });

  final String conversationId;
  final ValueChanged<String>? onMessageTap;

  @override
  Widget build(BuildContext context) {
    return MessageExtrasSheet(
      kind: MessageExtrasKind.pinned,
      conversationId: conversationId,
      onMessageTap: onMessageTap,
    );
  }
}
