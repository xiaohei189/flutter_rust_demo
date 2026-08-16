import 'package:flutter/material.dart';

import '../../previews/app_theme_preview.dart';
import '../../core/theme/app_theme.dart';

/// 多选转发操作栏
class MessageSelectionBar extends StatelessWidget {
  const MessageSelectionBar({
    super.key,
    required this.count,
    required this.onForwardOneByOne,
    required this.onMergeForward,
    required this.onClose,
  });

  final int count;
  final VoidCallback onForwardOneByOne;
  final VoidCallback onMergeForward;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '已选 $count 条',
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
          ),
          TextButton(onPressed: onForwardOneByOne, child: const Text('逐条转发')),
          TextButton(onPressed: onMergeForward, child: const Text('合并转发')),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '多选操作栏（已选 3 条）', group: 'MessageSelectionBar')
Widget messageSelectionBarPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: MessageSelectionBar(
      count: 3,
      onForwardOneByOne: _noop,
      onMergeForward: _noop,
      onClose: _noop,
    ),
  );
}

void _noop() {}
