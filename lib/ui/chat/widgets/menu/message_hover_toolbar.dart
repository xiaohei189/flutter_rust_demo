import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';

/// 同一种消息表情反应的聚合结果。
class MessageReactionGroup {
  const MessageReactionGroup({
    required this.emoji,
    required this.count,
    this.names = const [],
  });

  final String emoji;
  final int count;
  final List<String> names;
}

/// 消息反应展示（对齐飞书稿）：按「人」展开，一个小胶囊 = 表情 + 昵称，
/// 多个胶囊自动换行；气泡内展示，底色跟随气泡深浅。
class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.groups,
    this.isFromMe = false,
  });

  final List<MessageReactionGroup> groups;

  /// 是否是自己的消息（决定胶囊底色 / 文字颜色）
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [for (final group in groups) ..._chipsOf(group)],
    );
  }

  /// 有昵称时每人一个胶囊（稿子里的样子）；没有昵称时退化为「表情 + 数量」。
  List<Widget> _chipsOf(MessageReactionGroup group) {
    if (group.names.isEmpty) {
      return [
        _ReactionChip(
          emoji: group.emoji,
          name: group.count > 1 ? '+${group.count}' : null,
          isFromMe: isFromMe,
          tooltip: '${group.count} 人',
        ),
      ];
    }
    return [
      for (final name in group.names)
        _ReactionChip(
          emoji: group.emoji,
          name: name,
          isFromMe: isFromMe,
          tooltip: '$name 回复了 ${group.emoji}',
        ),
    ];
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.isFromMe,
    this.name,
    this.tooltip,
  });

  final String emoji;
  final String? name;
  final bool isFromMe;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // 自己气泡是饱和主色 → 半透明白底 + 白字；对方气泡浅色 → 白底 + 深字
    final textColor = isFromMe ? Colors.white : colors.bubbleOtherText;
    final chipColor = isFromMe
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.6);
    return Tooltip(
      message: tooltip ?? emoji,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (name != null) ...[
              const SizedBox(width: 5),
              Container(
                width: 1,
                height: 12,
                color: textColor.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 76),
                child: Text(
                  name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '消息反应', group: 'MessageReactionBar')
Widget messageReactionBarPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: MessageReactionBar(
      groups: [
        MessageReactionGroup(emoji: '👍', count: 3, names: ['张三', '李四', '王五']),
        MessageReactionGroup(emoji: '❤️', count: 1, names: ['我']),
      ],
    ),
  );
}
