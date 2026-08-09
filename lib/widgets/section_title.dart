import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../theme/app_theme.dart';

/// 区块标题组件
/// 用于卡片内部的区块分隔标题
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.style,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: style ??
            TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
            ),
      ),
    );
  }
}

/// 带图标的区块标题组件
class SectionTitleWithIcon extends StatelessWidget {
  const SectionTitleWithIcon({
    super.key,
    required this.title,
    required this.icon,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final EdgeInsetsGeometry padding;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor ?? AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

@Preview(name: '基础标题', group: 'SectionTitle')
Widget sectionTitlePreview() {
  return const SectionTitle(title: '好友动态');
}

@Preview(name: '带图标标题', group: 'SectionTitle')
Widget sectionTitleWithIconPreview() {
  return const SectionTitleWithIcon(title: '群公告', icon: Icons.campaign);
}
