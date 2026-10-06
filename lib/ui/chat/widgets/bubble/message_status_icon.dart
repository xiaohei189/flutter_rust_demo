import 'package:flutter/material.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/message.dart' show MessageSendStatus;
import '../../../core/theme/app_theme.dart';

/// 消息发送状态图标：发送中/失败/已读/已发送。
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({super.key, required this.message, this.onRetry});

  final ChatMessage message;

  /// 发送失败时点按重发（对齐飞书/微信：点失败标记即可重发）
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = MessageSendStatus.fromValue(message.status);
    if (status == MessageSendStatus.sending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
        ),
      );
    }
    if (status == MessageSendStatus.sendFailed) {
      return GestureDetector(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 扩大热区，避免 16px 图标难点中
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.error_outline, size: 16, color: colors.danger),
        ),
      );
    }
    if (message.isRead) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: colors.success,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.done, size: 11, color: colors.onPrimary),
      );
    }
    if (status == MessageSendStatus.sendSuccess) {
      return Icon(Icons.done, size: 16, color: colors.textSecondary);
    }
    return const SizedBox.shrink();
  }
}
