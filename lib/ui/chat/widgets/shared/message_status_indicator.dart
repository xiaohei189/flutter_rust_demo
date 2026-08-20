import 'package:flutter/material.dart';
import 'package:flutter_rust_demo/domain/models/message.dart';
import 'package:flutter_rust_demo/ui/previews/app_theme_preview.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

/// 消息状态指示器组件
class MessageStatusIndicator extends StatelessWidget {
  final MessageSendStatus status;
  final VoidCallback? onRetry;

  const MessageStatusIndicator({super.key, required this.status, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    switch (status) {
      case MessageSendStatus.sending:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
          ),
        );

      case MessageSendStatus.sendSuccess:
        return const SizedBox.shrink();

      case MessageSendStatus.sendFailed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(Icons.error_outline, size: 18, color: colors.danger),
        );

      case MessageSendStatus.hasDeleted:
        return const SizedBox.shrink();
    }
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '发送中', group: 'MessageStatusIndicator')
Widget messageStatusSendingPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: MessageStatusIndicator(status: MessageSendStatus.sending),
  );
}

@AppThemePreview(name: '发送失败（可重试）', group: 'MessageStatusIndicator')
Widget messageStatusFailedPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: MessageStatusIndicator(status: MessageSendStatus.sendFailed),
  );
}
