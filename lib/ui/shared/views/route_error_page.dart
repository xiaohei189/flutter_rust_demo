import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

/// 统一错误页 - 用于路由错误（404）与参数缺失兜底
class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({super.key, this.message, this.showBackButton = true});

  /// 错误描述；为空时显示默认文案
  final String? message;

  /// 是否显示返回按钮（404 页为 false，参数兜底为 true）
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? l10n?.routeNotFound ?? '页面不存在',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (showBackButton) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: Text(l10n?.goBack ?? '返回'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
