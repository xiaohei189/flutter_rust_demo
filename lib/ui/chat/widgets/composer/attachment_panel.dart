import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';

/// 附件面板项定义
class AttachmentItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const AttachmentItem({required this.icon, required this.label, this.onTap});
}

/// 附件 Grid 面板：在输入区上方展开，4 列宫格布局
class AttachmentPanel extends StatelessWidget {
  final List<AttachmentItem> items;
  final VoidCallback? onItemTap;

  const AttachmentPanel({super.key, required this.items, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.attachmentBackground,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) => _buildItem(context, item)).toList(),
      ),
    );
  }

  Widget _buildItem(BuildContext context, AttachmentItem item) {
    final colors = context.appColors;
    final enabled = item.onTap != null;
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: () {
          item.onTap?.call();
          onItemTap?.call();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: enabled
                    ? colors.primary.withValues(alpha: 0.08)
                    : colors.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                item.icon,
                size: 28,
                color: enabled ? colors.primary : colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? colors.textPrimary
                    : colors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
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
        AttachmentItem(icon: Icons.photo_library_outlined, label: '相册'),
        AttachmentItem(icon: Icons.camera_alt_outlined, label: '拍照'),
        AttachmentItem(icon: Icons.videocam_outlined, label: '视频'),
        AttachmentItem(icon: Icons.location_on_outlined, label: '位置'),
        AttachmentItem(icon: Icons.insert_drive_file_outlined, label: '文件'),
        AttachmentItem(icon: Icons.person_add_outlined, label: '名片'),
      ],
    ),
  );
}
