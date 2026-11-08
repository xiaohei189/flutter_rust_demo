import 'package:shared_preferences/shared_preferences.dart';

/// 话题文本草稿的本地持久化。
///
/// 键按「群发布」或「具体话题回复」隔离，避免切换页面时互相覆盖。
class TopicDraftStore {
  const TopicDraftStore();

  static const _rootPrefix = 'topic_draft_root_';
  static const _replyPrefix = 'topic_draft_reply_';

  Future<String> loadRoot(String groupId) => _load('$_rootPrefix$groupId');

  Future<void> saveRoot(String groupId, String text) =>
      _save('$_rootPrefix$groupId', text);

  Future<void> clearRoot(String groupId) =>
      _clear('$_rootPrefix$groupId');

  Future<String> loadReply(String topicId) => _load('$_replyPrefix$topicId');

  Future<void> saveReply(String topicId, String text) =>
      _save('$_replyPrefix$topicId', text);

  Future<void> clearReply(String topicId) =>
      _clear('$_replyPrefix$topicId');

  Future<String> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? '';
  }

  Future<void> _save(String key, String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, text);
    }
  }

  Future<void> _clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
