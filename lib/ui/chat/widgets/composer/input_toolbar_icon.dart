import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 输入工具栏等宽图标按钮（飞书风格：24px 线性图标）。
class InputToolbarIcon extends StatelessWidget {
  const InputToolbarIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.active = false,
    this.size,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  /// 按钮尺寸（图标 24 居中）：null 时用默认 28；传更小值可单独缩小某按钮、收紧它与相邻元素的间距
  final double? size;
  final void Function(LongPressStartDetails)? onLongPressStart;
  final void Function(LongPressMoveUpdateDetails)? onLongPressMoveUpdate;
  final void Function(LongPressEndDetails)? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final hasLongPress = onLongPressStart != null;
    final btn = Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: SizedBox(
          // 默认按钮尺寸（图标 24 居中）；可传 size 单独覆盖（如表情/更多用更小值收紧它们之间的间距）
          width: size ?? 28,
          height: size ?? 28,
          child: IconButton(
            icon: Icon(
              icon,
              size: 24,
              color: enabled
                  ? (active
                        ? context.appColors.primary
                        : context.appColors.textPrimary.withValues(alpha: 0.7))
                  : context.appColors.textSecondary.withValues(alpha: 0.3),
            ),
            onPressed: hasLongPress ? null : (enabled ? onTap : null),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
    if (hasLongPress) {
      return GestureDetector(
        onTap: enabled ? onTap : null,
        onLongPressStart: onLongPressStart,
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        onLongPressEnd: onLongPressEnd,
        child: btn,
      );
    }
    return btn;
  }
}
