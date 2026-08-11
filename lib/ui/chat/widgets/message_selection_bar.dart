import 'package:flutter/material.dart';

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
