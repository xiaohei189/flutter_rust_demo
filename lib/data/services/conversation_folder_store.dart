import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 会话自定义分组本地存储（SharedPreferences JSON）。
///
/// 结构：{ 分组名: [conversationId, ...] }。分组为空时删除该键。
class ConversationFolderStore {
  static const _key = 'conversation_folders_v1';

  Future<Map<String, List<String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, List<String>>{};
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is List) {
          result[entry.key] = value.whereType<String>().toList();
        }
      }
      return result;
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Future<void> save(Map<String, List<String>> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = Map<String, List<String>>.fromEntries(
      folders.entries.where((e) => e.value.isNotEmpty),
    );
    await prefs.setString(_key, jsonEncode(clean));
  }
}
