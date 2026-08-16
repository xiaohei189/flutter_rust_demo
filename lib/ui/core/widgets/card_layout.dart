import 'package:flutter/material.dart';

import '../../previews/app_theme_preview.dart';
import '../theme/app_theme.dart';

/// 卡片布局组件：提供统一的卡片样式、圆角与边距。
class CardLayout extends StatelessWidget {
  const CardLayout({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.padding,
    this.backgroundColor,
    this.borderRadius,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 带标题的卡片布局
class CardLayoutWithTitle extends StatelessWidget {
  const CardLayoutWithTitle({
    super.key,
    required this.title,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.backgroundColor,
    this.borderRadius,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return CardLayout(
      margin: margin,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

@AppThemePreview(name: '基础卡片', group: 'CardLayout')
Widget cardLayoutPreview() {
  return const CardLayout(
    padding: EdgeInsets.all(12),
    children: [Text('第一行内容'), SizedBox(height: 8), Text('第二行内容')],
  );
}

@AppThemePreview(name: '带标题卡片', group: 'CardLayout')
Widget cardLayoutWithTitlePreview() {
  return const CardLayoutWithTitle(
    title: '账号信息',
    children: [
      ListTile(leading: Icon(Icons.person_outline), title: Text('用户名')),
      ListTile(leading: Icon(Icons.phone_outlined), title: Text('手机号')),
    ],
  );
}
