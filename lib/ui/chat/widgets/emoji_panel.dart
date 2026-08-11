import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 表情面板：最近使用 + 默认表情。
class EmojiPanel extends StatelessWidget {
  const EmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;

  static const List<String> commonEmojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '🥲',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😧',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '❤️',
    '🔥',
    '⭐',
    '🎉',
    '🎊',
    '💯',
    '✅',
    '❌',
    '⚡',
    '🌟',
    '💫',
  ];

  @override
  Widget build(BuildContext context) {
    const recentCount = 16;
    final recentEmojis = commonEmojis.take(recentCount).toList();
    final defaultEmojis = commonEmojis.skip(recentCount).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: context.appColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '最常使用',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildEmojiGrid(context, recentEmojis),
                  const SizedBox(height: 8),
                  Text(
                    '默认表情',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildEmojiGrid(context, defaultEmojis),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Icon(Icons.add, size: 20, color: Colors.grey),
                Icon(
                  Icons.emoji_emotions_outlined,
                  size: 20,
                  color: context.appColors.primary,
                ),
                const Icon(Icons.favorite_border, size: 20, color: Colors.grey),
                IconButton(
                  icon: Icon(
                    Icons.keyboard,
                    size: 20,
                    color: context.appColors.textSecondary,
                  ),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(BuildContext context, List<String> emojis) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (_, i) => InkWell(
        onTap: () => onEmojiSelected(emojis[i]),
        child: Center(
          child: Text(emojis[i], style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
