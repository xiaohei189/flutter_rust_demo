import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/message_extras.dart';

/// 消息级本地扩展存储（SharedPreferences JSON）。
///
/// 结构：`{ "conversationId|clientMsgId": { reactions: [...], pinned, pinnedAt } }`。
/// 空扩展（无表情、未置顶）不占空间，由 Notifier 在写入前剔除。
class MessageExtrasStore {
  static const _key = 'message_extras_v1';

  Future<Map<String, MessageExtras>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, MessageExtras>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, MessageExtras>{};
      final result = <String, MessageExtras>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final extras = MessageExtras.fromJson(
          value.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (extras.isEmpty) continue;
        result[entry.key] = extras;
      }
      return result;
    } catch (_) {
      return <String, MessageExtras>{};
    }
  }

  Future<void> save(Map<String, MessageExtras> extras) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{};
    for (final entry in extras.entries) {
      if (entry.value.isEmpty) continue;
      payload[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_key, jsonEncode(payload));
  }
}
