import 'dart:convert';

import '../../../../domain/models/chat_message.dart' show ChatMessage;

final Expando<Map<String, dynamic>> _parsedContentCache = Expando<Map<String, dynamic>>();

/// 解析消息 content JSON 并缓存，避免多个展示 getter 重复解析。
Map<String, dynamic> parsedContentOf(ChatMessage message) {
  final cached = _parsedContentCache[message];
  if (cached != null) return cached;
  if (message.content.isEmpty || !message.content.startsWith('{')) {
    return const {};
  }
  try {
    final decoded = jsonDecode(message.content) as Map<String, dynamic>;
    _parsedContentCache[message] = decoded;
    return decoded;
  } catch (_) {
    return const {};
  }
}