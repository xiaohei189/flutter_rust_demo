import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 录音状态浮层：默认提示“上滑取消”，上滑后变“松手取消”。
class RecordingOverlay extends StatelessWidget {
  const RecordingOverlay({super.key, required this.cancel});

  final bool cancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: colors.surface.withValues(alpha: 0.92),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            cancel ? Icons.keyboard_arrow_up : Icons.mic,
            size: 18,
            color: cancel ? colors.danger : colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            cancel ? '松手取消' : '上滑取消',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cancel ? colors.danger : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}