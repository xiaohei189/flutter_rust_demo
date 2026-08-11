import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 通用的列表行布局：左侧前导图标 + 标签、中间 Spacer、右侧尾随内容/箭头。
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.label,
    this.leading,
    this.value,
    this.placeholder,
    this.trailing,
    this.valueColor,
    this.showArrow = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  final String label;
  final Widget? leading;
  final String? value;
  final String? placeholder;
  final Widget? trailing;
  final Color? valueColor;
  final bool showArrow;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Text(
              label,
              style: TextStyle(fontSize: 16, color: colors.textPrimary),
            ),
            const Spacer(),
            if (trailing != null) ...[
              trailing!,
            ] else if (value != null && value!.isNotEmpty) ...[
              Text(
                value!,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? colors.textSecondary,
                ),
              ),
            ] else if (placeholder != null) ...[
              Text(
                placeholder!,
                style: TextStyle(fontSize: 15, color: colors.textSecondary),
              ),
            ],
            if (showArrow) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 双行列表项，用于标签 + 较长值场景。
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
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 16, color: colors.textPrimary),
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
                      ? colors.textSecondary
                      : colors.textSecondary.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.chevron_right,
                size: 22,
                color: colors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带箭头的可点击行，用于页面跳转。
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

/// 标签 + Switch 组合。
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
    final colors = context.appColors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: colors.textPrimary),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colors.primary.withValues(alpha: 0.5),
            activeThumbColor: colors.primary,
          ),
        ],
      ),
    );
  }
}

/// 统一的列表分隔线样式。
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
    return Divider(height: height, indent: indent, endIndent: endIndent);
  }
}

/// 危险操作行：红色文字居中按钮。
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
            style: TextStyle(fontSize: 15, color: context.appColors.danger),
          ),
        ),
      ),
    );
  }
}
