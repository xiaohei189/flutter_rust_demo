import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';

/// 附件面板的设计高度：输入区按它（与键盘高度取较大者）给面板占位。
const double kAttachmentPanelHeight = 320;

/// 附件面板项定义
class AttachmentItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// 图标颜色（飞书稿里每个入口一个色）
  final Color? color;

  const AttachmentItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });
}

/// 附件/功能入口的图标色板（飞书稿：每个入口一个颜色）。
///
/// 这是**装饰色**：只用于图标，不参与主题语义（不随 light/dark 切换），
/// 也不要用于文字、按钮、状态。蓝色与 `AppColors.primary` 的浅色取值统一
/// （历史遗留的 `#3370FF` 已并入），避免同一个应用里出现两个主蓝。
abstract final class AttachmentIconColors {
  static const blue = Color(0xFF007AFF);
  static const orange = Color(0xFFFF8A00);
  static const purple = Color(0xFF7F3BF5);
  static const green = Color(0xFF00B42A);
}

/// 附件 Grid 面板（飞书稿）：浅灰底 + 4 列白卡，卡片内彩色图标 + 下方标题
class AttachmentPanel extends StatelessWidget {
  final List<AttachmentItem> items;
  final VoidCallback? onItemTap;

  const AttachmentPanel({super.key, required this.items, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
      decoration: BoxDecoration(color: colors.attachmentBackground),
      // 高度受限时（小屏 / 键盘弹出）可滚动，避免 RenderFlex 溢出
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: kAttachmentPanelHeight),
        child: SingleChildScrollView(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildItem(context, items[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, AttachmentItem item) {
    final colors = context.appColors;
    final enabled = item.onTap != null;
    final iconColor = enabled
        ? (item.color ?? colors.primary)
        : colors.textSecondary.withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled
          ? () {
              item.onTap?.call();
              onItemTap?.call();
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 30, color: iconColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '默认附件面板', group: 'AttachmentPanel')
Widget attachmentPanelPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: AttachmentPanel(
      items: [
        AttachmentItem(
          icon: Icons.folder_open,
          label: '文件',
          color: AttachmentIconColors.orange,
        ),
        AttachmentItem(
          icon: Icons.calendar_today_outlined,
          label: '日程',
          color: AttachmentIconColors.orange,
        ),
        AttachmentItem(
          icon: Icons.location_on,
          label: '位置',
          color: AttachmentIconColors.blue,
        ),
        AttachmentItem(
          icon: Icons.photo_library_outlined,
          label: '相册',
          color: AttachmentIconColors.blue,
        ),
      ],
    ),
  );
}
