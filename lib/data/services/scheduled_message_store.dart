import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/scheduled_message.dart';

/// 定时消息本地存储（SharedPreferences JSON 数组）。
class ScheduledMessageStore {
  static const _key = 'scheduled_messages_v1';

  Future<List<ScheduledMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <ScheduledMessage>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ScheduledMessage>[];
      final result = <ScheduledMessage>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final message = ScheduledMessage.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (message != null) result.add(message);
      }
      return result;
    } catch (_) {
      return <ScheduledMessage>[];
    }
  }

  Future<void> save(List<ScheduledMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final message in messages) message.toJson()]),
    );
  }
}
