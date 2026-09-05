import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 底栏占位页：暂无对应功能时展示，保持与设计稿一致的 Tab 布局。
class PlaceholderTabScreen extends StatelessWidget {
  const PlaceholderTabScreen({
    super.key,
    required this.title,
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              '$title 建设中',
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
