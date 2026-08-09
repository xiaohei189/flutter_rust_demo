import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../theme/app_theme.dart';

/// 卡片布局组件
/// 提供统一的卡片样式：白色背景、圆角、边距
/// 用于设置页面、个人资料等场景
class CardLayout extends StatelessWidget {
  const CardLayout({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.padding,
    this.backgroundColor = Colors.white,
    this.borderRadius = 12,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;
  final Color backgroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
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
    this.backgroundColor = Colors.white,
    this.borderRadius = 12,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
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
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

@Preview(name: '基础卡片', group: 'CardLayout')
Widget cardLayoutPreview() {
  return const CardLayout(
    padding: EdgeInsets.all(12),
    children: [
      Text('第一行内容'),
      SizedBox(height: 8),
      Text('第二行内容'),
    ],
  );
}

@Preview(name: '带标题卡片', group: 'CardLayout')
Widget cardLayoutWithTitlePreview() {
  return const CardLayoutWithTitle(
    title: '账号信息',
    children: [
      ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('用户名'),
      ),
      ListTile(
        leading: Icon(Icons.phone_outlined),
        title: Text('手机号'),
      ),
    ],
  );
}
