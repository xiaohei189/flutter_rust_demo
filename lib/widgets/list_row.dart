import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 列表行组件
/// 通用的列表项布局：左侧标签、中间内容/值、右侧尾随图标
/// 支持点击、自定义尾随组件、值文本样式
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.label,
    this.value,
    this.placeholder,
    this.trailing,
    this.valueColor,
    this.showArrow = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  final String label;
  final String? value;
  final String? placeholder;
  final Widget? trailing;
  final Color? valueColor;
  final bool showArrow;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            if (trailing != null) ...[
              trailing!,
            ] else if (value != null && value!.isNotEmpty) ...[
              Text(
                value!,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? AppTheme.textSecondaryColor,
                ),
              ),
            ] else if (placeholder != null) ...[
              Text(
                placeholder!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
            if (showArrow) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 双行列表项组件
/// 用于需要显示标签和较长值的场景，如群名称、群描述
class TwoLineListRow extends StatelessWidget {
  const TwoLineListRow({
    super.key,
    required this.label,
    required this.value,
    this.placeholder,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final String label;
  final String value;
  final String? placeholder;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            Expanded(
              flex: 2,
              child: Text(
                value.isNotEmpty ? value : (placeholder ?? ''),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  color: value.isNotEmpty
                      ? AppTheme.textSecondaryColor
                      : AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导航行组件
/// 带箭头的可点击行，用于页面跳转
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.title,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  final String title;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      label: title,
      showArrow: true,
      onTap: onTap,
      padding: padding,
    );
  }
}

/// 开关行组件
/// 标签 + Switch 组合
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

/// 分隔线组件
/// 统一的列表分隔线样式
class ListDivider extends StatelessWidget {
  const ListDivider({
    super.key,
    this.indent = 16,
    this.endIndent = 16,
    this.height = 1,
  });

  final double indent;
  final double endIndent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

/// 危险操作行组件
/// 红色文字的居中按钮，用于退出、删除等操作
class DangerActionRow extends StatelessWidget {
  const DangerActionRow({
    super.key,
    required this.title,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
  });

  final String title;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.unreadRed,
            ),
          ),
        ),
      ),
    );
  }
}
