import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 话题只读接口的本地投影。
///
/// 缓存按登录用户隔离，只保存服务端原始响应，避免 UI 层感知缓存格式。
/// 写入失败不会影响在线请求；读取失败按缓存未命中处理。
class TopicReadCache {
  const TopicReadCache();

  static const _prefix = 'topic_read_cache_v1';

  String _storageKey(String userId, String key) => '$_prefix:$userId:$key';

  Future<void> write({
    required String userId,
    required String key,
    required Map<String, dynamic> data,
  }) async {
    if (userId.isEmpty || key.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey(userId, key),
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (_) {
      // 本地缓存不能影响在线主链路。
    }
  }

  Future<Map<String, dynamic>?> read({
    required String userId,
    required String key,
  }) async {
    if (userId.isEmpty || key.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(userId, key));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final marker = '$_prefix:$userId:';
    for (final key in prefs.getKeys().where((key) => key.startsWith(marker))) {
      await prefs.remove(key);
    }
  }
}
