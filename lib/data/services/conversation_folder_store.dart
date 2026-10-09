import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 会话自定义分组本地存储（SharedPreferences JSON）。
///
/// 结构：{ 分组名: [conversationId, ...] }。
///
/// 空分组（0 个会话）同样落盘：用户可以先建好分组再往里放会话；
/// 删除分组由 `ConversationFoldersNotifier.removeFolder` 显式触发，
/// 不能靠「列表为空」隐式清理，否则新建的分组重启后会消失。
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
    await prefs.setString(_key, jsonEncode(folders));
  }
}
