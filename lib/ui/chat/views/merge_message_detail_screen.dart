import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../domain/extensions/message_ext.dart';
import '../../../../generated/rust/constant/enums.dart' show SessionType;
import '../../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../contacts/widgets/contact_pick_item.dart';
import '../providers/message_service_provider.dart';

/// 合并转发消息详情页
/// 展示 MergeElem.multiMessage 中的子消息列表
class MergeMessageDetailScreen extends ConsumerWidget {
  final MessageInfo message;

  const MergeMessageDetailScreen({super.key, required this.message});

  String get _sourceConversationId {
    if (message.attachedInfo.isEmpty) return '';
    try {
      final map = jsonDecode(message.attachedInfo) as Map<String, dynamic>;
      return map['sourceConversationId'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _forwardMergeMessage(BuildContext context, WidgetRef ref) async {
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '转发给',
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final target = result.first;
    try {
      await ref
          .read(messageServiceProvider.notifier)
          .forwardMessage(
            clientMsgId: message.clientMsgId,
            sourceId: target.id,
            sessionType: target.isGroup
                ? SessionType.writeGroupChat
                : SessionType.singleChat,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已转发给 ${target.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('转发失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final json = message.parsedContent;
    final title = json['title'] as String? ?? '聊天记录';
    final subMessages = _parseSubMessages(json);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: colors.background,
        foregroundColor: colors.bubbleOtherText,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: '转发',
            icon: const Icon(Icons.forward_rounded),
            onPressed: () => _forwardMergeMessage(context, ref),
          ),
          if (_sourceConversationId.isNotEmpty)
            IconButton(
              tooltip: '查看原会话',
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  AppRouter.goToChatDetailById(context, _sourceConversationId),
            ),
        ],
      ),
      body: subMessages.isEmpty
          ? const Center(child: Text('暂无消息内容'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: subMessages.length,
              itemBuilder: (context, index) {
                final sub = subMessages[index];
                return _buildSubMessageItem(context, sub);
              },
            ),
    );
  }

  /// 从 content JSON 解析子消息列表
  List<_SubMessage> _parseSubMessages(Map<String, dynamic> json) {
    final multiMessage = json['multiMessage'];
    if (multiMessage is! List) return [];

    return multiMessage.map<_SubMessage>((item) {
      final msg = item as Map<String, dynamic>;
      final senderNickname = msg['senderNickname'] as String? ?? '';
      final contentType = msg['contentType'] as int? ?? 0;
      final content = msg['content'] as String? ?? '';
      final sendTime = msg['sendTime'] as int? ?? 0;

      String displayContent;
      try {
        final contentJson = jsonDecode(content) as Map<String, dynamic>;
        displayContent = _extractContent(contentJson, contentType);
      } catch (_) {
        displayContent = content;
      }

      return _SubMessage(
        senderNickname: senderNickname,
        content: displayContent,
        contentType: contentType,
        sendTime: sendTime,
      );
    }).toList();
  }

  /// 根据 contentType 提取显示内容
  String _extractContent(Map<String, dynamic> json, int contentType) {
    return switch (contentType) {
      101 => json['content'] as String? ?? '',
      102 => '[图片]',
      103 => '[语音]',
      104 => '[视频]',
      105 => json['fileName'] as String? ?? '[文件]',
      106 => json['text'] as String? ?? '[@消息]',
      107 => '[聊天记录]',
      108 => json['nickname'] as String? ?? '[名片]',
      109 => json['description'] as String? ?? '[位置]',
      110 => json['data'] as String? ?? '[自定义]',
      114 => json['text'] as String? ?? '[引用]',
      116 => json['text'] as String? ?? '[@消息]',
      _ => json['content'] as String? ?? '[消息]',
    };
  }

  IconData _contentIcon(int contentType) {
    return switch (contentType) {
      102 => Icons.image_outlined,
      103 => Icons.mic_none,
      104 => Icons.videocam_outlined,
      105 => Icons.insert_drive_file_outlined,
      106 || 116 => Icons.alternate_email,
      107 => Icons.library_books_outlined,
      108 => Icons.contact_page_outlined,
      109 => Icons.location_on_outlined,
      114 => Icons.format_quote_outlined,
      _ => Icons.chat_bubble_outline,
    };
  }

  String _formatSendTime(int timeMs) {
    if (timeMs <= 0) return '';
    final time = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildSubMessageItem(BuildContext context, _SubMessage sub) {
    final colors = context.appColors;
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: sub.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                _contentIcon(sub.contentType),
                size: 18,
                color: colors.textSecondary,
              ),
            ),
            Text(
              '${sub.senderNickname}：',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.bubbleOtherText,
              ),
            ),
            Expanded(
              child: Text(
                sub.content,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sub.sendTime > 0) ...[
              const SizedBox(width: 8),
              Text(
                _formatSendTime(sub.sendTime),
                style: TextStyle(
                  fontSize: 11,
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

class _SubMessage {
  final String senderNickname;
  final String content;
  final int contentType;
  final int sendTime;

  const _SubMessage({
    required this.senderNickname,
    required this.content,
    required this.contentType,
    this.sendTime = 0,
  });
}
