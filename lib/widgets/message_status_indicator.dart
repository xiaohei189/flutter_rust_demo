import 'package:flutter/material.dart';
import 'package:flutter_rust_demo/models/message.dart';

/// 消息状态指示器组件
class MessageStatusIndicator extends StatelessWidget {
  final MessageSendStatus status;
  final VoidCallback? onRetry;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageSendStatus.sending:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.grey.shade400,
            ),
          ),
        );

      case MessageSendStatus.sendSuccess:
        return Icon(
          Icons.check,
          size: 16,
          color: Colors.grey.shade600,
        );

      case MessageSendStatus.sendFailed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(
            Icons.error_outline,
            size: 18,
            color: Colors.red,
          ),
        );

      case MessageSendStatus.hasDeleted:
        return const SizedBox.shrink();
    }
  }
}
