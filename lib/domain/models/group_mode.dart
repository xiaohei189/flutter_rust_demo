import 'dart:convert';

/// 群模式：决定群内内容按什么维度组织（对齐飞书「群模式」）。
///
/// - [chat]：对话群，消息按发送先后顺序排列（默认）；
/// - [topic]：话题群，内容按话题聚合（需要服务端支持，见 docs/create-group-plan.md）。
enum GroupMode {
  chat,
  topic;

  bool get isTopic => this == GroupMode.topic;

  int get wireValue => this == GroupMode.topic ? 2 : 1;

  static GroupMode fromEx(String ex) {
    if (ex.trim().isEmpty) return GroupMode.chat;
    try {
      final decoded = jsonDecode(ex);
      if (decoded is! Map) return GroupMode.chat;
      final value = decoded['openim_topic'];
      if (value is Map && value['mode'] == 2) return GroupMode.topic;
    } catch (_) {}
    return GroupMode.chat;
  }

  String encodeEx({String existing = '', int version = 1, int sinceSeq = 0}) {
    final values = <String, dynamic>{};
    if (existing.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existing);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            values[entry.key.toString()] = entry.value;
          }
        }
      } catch (_) {}
    }
    values['openim_topic'] = <String, dynamic>{
      'mode': wireValue,
      'modeSinceSeq': sinceSeq,
      'version': version,
    };
    return jsonEncode(values);
  }
}
