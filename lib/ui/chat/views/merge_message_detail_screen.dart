import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../domain/extensions/message_ext.dart';
import '../../../../domain/models/message.dart' show MessageType;
import '../../../../domain/models/user.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../providers/message_service_provider.dart';
import '../widgets/media_viewer.dart';
import '../widgets/bubble/message_bubble.dart';

/// 合并转发消息详情页
///
/// 展示 `MergeElem.multiMessage` 中的完整子消息（复用 [MessageBubble] 渲染
/// 图片/语音/视频等真实内容）；`multiMessage` 缺失时回退到 `abstractList`
/// 摘要文本行。通过 [AppRouter.goToMergeMessage] 以路由打开。
class MergeMessageDetailScreen extends ConsumerWidget {
  final ChatMessage message;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final json = message.parsedContent;
    final title = json['title'] as String? ?? '聊天记录';
    final items = _parseItems(json);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: colors.background,
        foregroundColor: colors.bubbleOtherText,
        elevation: 0.5,
        actions: [
          if (_sourceConversationId.isNotEmpty)
            IconButton(
              tooltip: '查看原会话',
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  AppRouter.goToChatDetailById(context, _sourceConversationId),
            ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('暂无消息内容'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final message = item.message;
                return message != null
                    ? _buildMessageBubble(context, ref, message)
                    : _buildFallbackRow(context, item.fallback!);
              },
            ),
    );
  }

  /// 解析展示项：multiMessage 子消息优先渲染真实气泡；内容缺失时
  /// 回退到 abstractList 摘要文本行。
  List<_MergeItem> _parseItems(Map<String, dynamic> json) {
    final multiMessage = json['multiMessage'];
    final rows = _parseAbstractRows(json);
    if (multiMessage is! List || multiMessage.isEmpty) {
      return rows.map(_MergeItem.fallback).toList();
    }

    final items = <_MergeItem>[];
    for (final (index, rawItem) in multiMessage.indexed) {
      if (rawItem is! Map<String, dynamic>) continue;
      final sub = mergeSubMessageFromJson(rawItem);
      if (sub.content.isEmpty && index < rows.length) {
        items.add(_MergeItem.fallback(rows[index]));
      } else {
        items.add(_MergeItem.message(sub));
      }
    }
    return items;
  }

  /// 用 [MessageBubble] 渲染子消息（图片/语音/视频等真实展示）。
  Widget _buildMessageBubble(
    BuildContext context,
    WidgetRef ref,
    ChatMessage sub,
  ) {
    final currentUserId = ref.read(messageServiceProvider).currentUserId;
    final isFromMe = sub.sendId.isNotEmpty && sub.sendId == currentUserId;
    final nickname = sub.senderNickname;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFromMe && nickname.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 8, bottom: 2),
            child: Text(
              nickname,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textSecondary,
              ),
            ),
          ),
        MessageBubble(
          message: sub,
          otherUser: User(
            id: sub.sendId,
            name: nickname.isNotEmpty ? nickname : '用户',
            avatar: sub.senderFaceUrl.isNotEmpty ? sub.senderFaceUrl : null,
          ),
          currentUserId: currentUserId,
          onTap:
              sub.messageType == MessageType.image &&
                  sub.displayImageSource.isNotEmpty
              ? (msg) => openImagePreview(
                  context,
                  source: msg.displayImageSource,
                  suggestedName: '图片',
                )
              : null,
        ),
      ],
    );
  }

  /// 从 content JSON 解析 abstractList 摘要文本行（multiMessage 缺失时兜底）。
  List<_SubMessage> _parseAbstractRows(Map<String, dynamic> json) {
    final abstractList = json['abstractList'];
    if (abstractList is! List) return [];
    return abstractList.map((item) {
      final raw = item is String ? item : item.toString();
      final separator = raw.indexOf(RegExp('[:：]'));
      if (separator > 0) {
        return _SubMessage(
          senderNickname: raw.substring(0, separator),
          content: raw.substring(separator + 1).trim(),
          contentType: 0,
        );
      }
      return _SubMessage(senderNickname: '摘要', content: raw, contentType: 0);
    }).toList();
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

  Widget _buildFallbackRow(BuildContext context, _SubMessage sub) {
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

  const _SubMessage({
    required this.senderNickname,
    required this.content,
    required this.contentType,
  });
}

class _MergeItem {
  final ChatMessage? message;
  final _SubMessage? fallback;

  const _MergeItem.message(this.message) : fallback = null;
  const _MergeItem.fallback(this.fallback) : message = null;
}
