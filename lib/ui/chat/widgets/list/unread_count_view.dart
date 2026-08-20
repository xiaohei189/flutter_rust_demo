import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';

/// 未读数角标：红色小圆点（数字或单纯红点）
class UnreadCountView extends StatelessWidget {
  const UnreadCountView({super.key, this.count = 0, this.size = 18});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : '$count';
    final colors = context.appColors;
    return Container(
      alignment: Alignment.center,
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
        maxWidth: count > 99 ? size * 1.8 : size,
      ),
      decoration: BoxDecoration(
        color: colors.danger,
        shape: count > 99 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: count > 99 ? BorderRadius.circular(size / 2) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: context.appColors.onPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

@AppThemePreview(name: '未读数 5', group: 'UnreadCountView')
Widget unreadCountViewNumberPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: UnreadCountView(count: 5),
  );
}

@AppThemePreview(name: '未读数 99+', group: 'UnreadCountView')
Widget unreadCountViewMaxPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: UnreadCountView(count: 128),
  );
}

@AppThemePreview(name: '未读数 0（隐藏）', group: 'UnreadCountView')
Widget unreadCountViewZeroPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: UnreadCountView(count: 0),
  );
}
