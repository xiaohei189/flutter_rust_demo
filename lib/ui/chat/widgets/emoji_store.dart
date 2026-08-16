import 'package:shared_preferences/shared_preferences.dart';

/// 表情使用记录存储：最近使用 + 收藏（SharedPreferences 持久化）。
///
/// 最近使用按使用时间排序（最近用的排最前），上限 30 个；
/// 收藏为手动收藏列表（长按表情收藏/取消）。
class EmojiStore {
  static const String _recentKey = 'emoji_recent';
  static const String _favoriteKey = 'emoji_favorites';
  static const int _maxRecent = 30;

  EmojiStore._();

  /// 读取最近使用列表（最近用的排最前）
  static Future<List<String>> loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  /// 记录一次使用：去重置顶，保留最多 [_maxRecent] 个
  static Future<List<String>> recordUse(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentKey) ?? <String>[];
    recent.remove(emoji);
    recent.insert(0, emoji);
    if (recent.length > _maxRecent) {
      recent.removeRange(_maxRecent, recent.length);
    }
    await prefs.setStringList(_recentKey, recent);
    return recent;
  }

  /// 读取收藏列表
  static Future<List<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoriteKey) ?? const [];
  }

  /// 收藏 / 取消收藏，返回更新后的收藏列表
  static Future<List<String>> toggleFavorite(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoriteKey) ?? <String>[];
    if (favorites.contains(emoji)) {
      favorites.remove(emoji);
    } else {
      favorites.insert(0, emoji);
    }
    await prefs.setStringList(_favoriteKey, favorites);
    return favorites;
  }
}
