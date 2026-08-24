import 'dart:convert';

/// 会话草稿文本，持久化在 `Conversation.draftText`（`{"text": "..."}`）。
class ConversationDraft {
  const ConversationDraft._();

  /// 从 draftText 原始值解析纯文本：
  /// - 空字符串返回 null；
  /// - JSON 且含非空 `text` 时返回该文本；
  /// - JSON 但无有效 `text` key 时返回 null（调用方回退最新消息）；
  /// - 非 JSON 时原样返回（兼容旧数据直接存纯文本）。
  static String? textOf(String draftText) {
    if (draftText.isEmpty) return null;
    try {
      final decoded = jsonDecode(draftText);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text'];
        if (text is String && text.isNotEmpty) return text;
        return null;
      }
      return null;
    } catch (_) {
      return draftText;
    }
  }

  /// 构建草稿持久化值。
  static String encode(String text) => jsonEncode({'text': text});
}
