import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 多选转发时的进度横幅：进度文案、进度条、取消按钮。
class ForwardProgressBanner extends StatelessWidget {
  const ForwardProgressBanner({
    super.key,
    required this.done,
    required this.total,
    required this.onCancel,
  });

  final int done;
  final int total;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Text(
            '转发中 $done/$total',
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 3,
              backgroundColor: context.appColors.surfaceMuted,
              color: context.appColors.primary,
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('取消')),
        ],
      ),
    );
  }
}
