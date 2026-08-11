import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 搜索分类 chip
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: colors.textSecondary.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            color: isSelected ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
