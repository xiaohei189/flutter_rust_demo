import 'package:flutter/material.dart';

import '../../previews/app_theme_preview.dart';
import '../theme/app_theme.dart';

/// 统一空状态视图。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: colors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 统一错误状态视图。
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: colors.danger.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '空状态（带副标题）', group: 'StateViews')
Widget emptyStatePreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: EmptyState(
      icon: Icons.chat_bubble_outline,
      title: '暂无消息',
      subtitle: '开始你的第一条消息吧',
    ),
  );
}

@AppThemePreview(name: '错误状态（可重试）', group: 'StateViews')
Widget errorStatePreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: ErrorState(message: '网络连接失败，请检查网络后重试', onRetry: _noop),
  );
}

void _noop() {}
