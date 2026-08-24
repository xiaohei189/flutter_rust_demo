import 'dart:convert';

import 'conversation.dart';

/// 会话本地标记（flagged/done/unread/archived），持久化在会话 `ex` JSON 中。
///
/// 仅本地生效（微信「标记/已完成/标为未读/归档」语义），不参与服务端同步。
class ConversationFlags {
  final bool flagged;
  final bool done;
  final bool markedUnread;
  final bool archived;

  const ConversationFlags({
    this.flagged = false,
    this.done = false,
    this.markedUnread = false,
    this.archived = false,
  });

  static const empty = ConversationFlags();

  /// 从会话 `ex` 字段解析标记；为空或非法 JSON 时返回空标记。
  factory ConversationFlags.parse(String ex) {
    if (ex.trim().isEmpty) return empty;
    try {
      final decoded = jsonDecode(ex);
      if (decoded is Map<String, dynamic>) {
        return ConversationFlags(
          flagged: decoded['flagged'] == true,
          done: decoded['done'] == true,
          markedUnread: decoded['unread'] == true,
          archived: decoded['archived'] == true,
        );
      }
    } catch (_) {}
    return empty;
  }

  factory ConversationFlags.fromConversation(Conversation conversation) =>
      ConversationFlags.parse(conversation.ex);

  ConversationFlags copyWith({
    bool? flagged,
    bool? done,
    bool? markedUnread,
    bool? archived,
  }) {
    return ConversationFlags(
      flagged: flagged ?? this.flagged,
      done: done ?? this.done,
      markedUnread: markedUnread ?? this.markedUnread,
      archived: archived ?? this.archived,
    );
  }

  /// 将当前标记合并进现有 `ex` JSON（保留其他自定义 key）。
  String encodeMerged(String currentEx) {
    Map<String, dynamic> map;
    if (currentEx.trim().isEmpty) {
      map = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(currentEx);
        map = decoded is Map<String, dynamic>
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
      } catch (_) {
        map = <String, dynamic>{};
      }
    }
    map['flagged'] = flagged;
    map['done'] = done;
    map['unread'] = markedUnread;
    map['archived'] = archived;
    return jsonEncode(map);
  }

  /// 展示用未读数：本地标未读时至少显示 1。
  int effectiveUnreadCount(Conversation conversation) {
    final unread = conversation.unreadCount;
    return markedUnread ? (unread < 1 ? 1 : unread) : unread;
  }
}
