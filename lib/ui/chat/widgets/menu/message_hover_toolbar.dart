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

/// 消息反应聚合展示：同一种表情只显示一个小胶囊，数量与昵称可查看。
class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.groups,
  });

  final List<MessageReactionGroup> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: groups
          .map((group) => _ReactionChip(group: group))
          .toList(),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.group});

  final MessageReactionGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = group.count > 1
        ? '${group.emoji} +${group.count - 1}'
        : group.emoji;
    final names = group.names;
    final tooltip = names.isEmpty
        ? null
        : names.length > 3
            ? '${names.take(3).join('、')} +${names.length - 3}'
            : names.join('、');
    return Tooltip(
      message: tooltip ?? label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
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
