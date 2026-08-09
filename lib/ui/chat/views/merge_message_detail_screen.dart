import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../domain/models/message_ext.dart';
import '../../../../src/rust/model/message.dart' show MessageInfo;
import '../../../../ui/core/theme/app_theme.dart';

/// 合并转发消息详情页
/// 展示 MergeElem.multiMessage 中的子消息列表
class MergeMessageDetailScreen extends StatelessWidget {
  final MessageInfo message;

  const MergeMessageDetailScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final json = message.parsedContent;
    final title = json['title'] as String? ?? '聊天记录';
    final subMessages = _parseSubMessages(json);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        foregroundColor: AppTheme.otherMessageTextColor,
        elevation: 0.5,
      ),
      body: subMessages.isEmpty
          ? const Center(child: Text('暂无消息内容'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: subMessages.length,
              itemBuilder: (context, index) {
                final sub = subMessages[index];
                return _buildSubMessageItem(sub);
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
      );
    }).toList();
  }

  /// 根据 contentType 提取显示内容
  String _extractContent(Map<String, dynamic> json, int contentType) {
    return switch (contentType) {
      101 => json['content'] as String? ?? '',
      102 => '[图片]',
      103 => '[视频]',
      104 => '[语音]',
      105 => json['fileName'] as String? ?? '[文件]',
      107 => '[聊天记录]',
      108 => json['nickname'] as String? ?? '[名片]',
      110 => json['data'] as String? ?? '[自定义]',
      114 => json['text'] as String? ?? '[引用]',
      116 => json['text'] as String? ?? '[@消息]',
      _ => json['content'] as String? ?? '[消息]',
    };
  }

  Widget _buildSubMessageItem(_SubMessage sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sub.senderNickname}：',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.otherMessageTextColor,
            ),
          ),
          Expanded(
            child: Text(
              sub.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
