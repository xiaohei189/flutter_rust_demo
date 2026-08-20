import 'dart:convert';

import '../../../../domain/models/message_search_result.dart' show MessageSearchResult;
import '../../../../domain/models/message.dart'
    show MessageType, messageTypeFromContentType;
import 'message_system_text.dart' show readableSystemMessage;

final Expando<Map<String, dynamic>> _parsedContentCache = Expando<Map<String, dynamic>>();

extension MessageSearchResultExt on MessageSearchResult {
  MessageType get messageType => messageTypeFromContentType(contentType);

  Map<String, dynamic> get parsedContent {
    final cached = _parsedContentCache[this];
    if (cached != null) return cached;
    if (content.isEmpty || !content.startsWith('{')) return const {};
    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      _parsedContentCache[this] = decoded;
      return decoded;
    } catch (_) {
      return const {};
    }
  }

  String get displayText {
    final json = parsedContent;
    return switch (messageType) {
      MessageType.text => json['content'] as String? ?? content,
      MessageType.advancedText => json['content'] as String? ?? '',
      MessageType.markdown => json['content'] as String? ?? '',
      MessageType.quote => json['text'] as String? ?? '',
      MessageType.at => json['text'] as String? ?? '',
      MessageType.image => '[图片]',
      MessageType.video => '[视频]',
      MessageType.audio => '[语音]',
      MessageType.file => '[文件]',
      MessageType.location => '[位置]',
      MessageType.card => '[名片]',
      MessageType.merge => '[聊天记录]',
      MessageType.system => _systemDisplayText(json),
      _ => content,
    };
  }

  String _systemDisplayText(Map<String, dynamic> json) =>
      readableSystemMessage(json, content);
}

