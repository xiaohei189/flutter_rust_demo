import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 下拉菜单卡片宽度（飞书稿约屏宽 45%，这里取定值，过长文案交给 ellipsis）。
const double kAppDropdownMenuWidth = 184;

/// 下拉菜单单行高度。
const double kAppDropdownMenuItemHeight = 48;

/// 卡片上下内边距。
const double _kVerticalPadding = 6;

/// 行内左侧图标大小（对齐飞书稿的线性图标）。
const double _kIconSize = 22;

/// 图标与文案间距。
const double _kIconGap = 14;

/// 行文案字号。
const double _kLabelFontSize = 16;

/// 卡片与屏幕右边缘、扫描入口动画的对齐留白。
const double _kScreenMargin = 12;

/// 下拉菜单里的一行：线性图标 + 文案。
class AppMenuItem {
  const AppMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 行 key，便于测试与驱动点击定位。
  final Key? key;
}

/// 飞书风格的下拉菜单卡片：白底、圆角、轻阴影，一行一图标 + 一行文案。
///
/// 只负责画卡片，弹出位置由 [showAppDropdownMenu] 计算。
class AppDropdownMenu extends StatelessWidget {
  const AppDropdownMenu({
    super.key,
    required this.items,
    this.width = kAppDropdownMenuWidth,
  });

  final List<AppMenuItem> items;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: colors.cardShadow,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: radius,
        // 圆角裁掉水波纹溢出，保证高亮不超出卡片
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _kVerticalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items) _AppDropdownMenuRow(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppDropdownMenuRow extends StatelessWidget {
  const _AppDropdownMenuRow({required this.item});

  final AppMenuItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      key: item.key,
      onTap: () {
        // 先收起菜单再执行动作：动作里通常要 push 新页面，
        // 不先 pop 的话菜单退场动画会和新页面叠在一起。
        Navigator.of(context).pop();
        item.onTap();
      },
      child: SizedBox(
        height: kAppDropdownMenuItemHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(item.icon, size: _kIconSize, color: colors.textPrimary),
              const SizedBox(width: _kIconGap),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _kLabelFontSize,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 在 [anchorKey] 对应控件的下方弹出下拉菜单。
///
/// 菜单右边缘与屏幕保持 [_kScreenMargin] 间距，顶部贴住锚点底部；
/// 遮罩全透明（飞书同款：不压暗背景），点击空白处收起。
Future<void> showAppDropdownMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AppMenuItem> items,
  double width = kAppDropdownMenuWidth,
}) {
  final screenSize = MediaQuery.sizeOf(context);
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final anchorBottom = anchorBox == null
      ? 56.0
      : anchorBox.localToGlobal(Offset(0, anchorBox.size.height)).dy;
  final menuHeight =
      items.length * kAppDropdownMenuItemHeight + _kVerticalPadding * 2;
  final top = math.max(
    AppTheme.spacingSm,
    math.min(anchorBottom + 6, screenSize.height - menuHeight - 24),
  );

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, _, __) => Stack(
      children: [
        // 显式铺一层吸收点击的空白区：菜单外的点击只收起菜单，
        // 不落到下面的列表行上（否则点空白处会顺手打开某个会话）。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(dialogContext).pop(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: top,
          right: _kScreenMargin,
          child: AppDropdownMenu(items: items, width: width),
        ),
      ],
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      // 从右上角「长」出来，贴合锚点方向
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}
