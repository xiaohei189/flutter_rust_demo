import 'package:flutter/material.dart';

/// 添加好友弹窗：输入验证消息后回调 [onSend]。
Future<void> showAddFriendDialog(
  BuildContext context, {
  required Future<void> Function(String reqMsg) onSend,
}) {
  final controller = TextEditingController();
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('添加好友'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: '输入验证消息（可选）',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            final reqMsg = controller.text.trim();
            Navigator.of(dialogContext).pop();
            await onSend(reqMsg);
          },
          child: const Text('发送'),
        ),
      ],
    ),
  );
}
