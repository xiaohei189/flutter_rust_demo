import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 联系人列表项
class ContactItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int badgeCount;
  final String trailingText;
  final VoidCallback onTap;

  const ContactItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.badgeCount = 0,
    this.trailingText = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(color: colors.surface, fontSize: 12),
              ),
            ),
          if (trailingText.isNotEmpty)
            Text(
              trailingText,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.divider),
        ],
      ),
      onTap: onTap,
    );
  }
}
