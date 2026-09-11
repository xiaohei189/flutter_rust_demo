import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';

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
      decoration: BoxDecoration(
        color: colors.attachmentBackground,
      ),
      // 高度受限时（小屏 / 键盘弹出）可滚动，避免 RenderFlex 溢出
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
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
          color: Color(0xFFFF8A00),
        ),
        AttachmentItem(
          icon: Icons.calendar_today_outlined,
          label: '日程',
          color: Color(0xFFFF8A00),
        ),
        AttachmentItem(
          icon: Icons.location_on,
          label: '位置',
          color: Color(0xFF3370FF),
        ),
        AttachmentItem(
          icon: Icons.photo_library_outlined,
          label: '相册',
          color: Color(0xFF3370FF),
        ),
      ],
    ),
  );
}
