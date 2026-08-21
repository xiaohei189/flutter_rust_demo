import 'package:flutter/material.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/message.dart' show MessageSendStatus;

/// 消息发送状态图标：发送中/失败/已读/已发送。
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final status = MessageSendStatus.fromValue(message.status);
    if (status == MessageSendStatus.sending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
        ),
      );
    }
    if (status == MessageSendStatus.sendFailed) {
      return const Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
    if (message.isRead) {
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Color(0xFF34C759),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.done, size: 11, color: Colors.white),
      );
    }
    if (status == MessageSendStatus.sendSuccess) {
      return Icon(Icons.done, size: 16, color: Colors.grey.shade400);
    }
    return const SizedBox.shrink();
  }
}
