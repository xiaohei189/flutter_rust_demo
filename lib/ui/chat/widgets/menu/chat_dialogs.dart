import 'package:flutter/material.dart';

import '../../mappers/message_display.dart';
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../core/theme/app_theme.dart';

Future<void> showLocationDetailDialog(BuildContext context, ChatMessage msg) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(msg.locationName.isNotEmpty ? msg.locationName : '位置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.locationDesc.isNotEmpty) ...[
            Text(msg.locationDesc),
            const SizedBox(height: 8),
          ],
          Text(
            '纬度: ${msg.latitude.toStringAsFixed(6)}\n'
            '经度: ${msg.longitude.toStringAsFixed(6)}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

Future<bool> showDeleteMessagesConfirm(BuildContext context, int count) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除选中消息'),
      content: Text('确定删除选中的 $count 条消息吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('删除', style: TextStyle(color: context.appColors.danger)),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}