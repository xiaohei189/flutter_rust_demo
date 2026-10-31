import '../../../domain/models/message_search_result.dart'
    show MessageSearchResult;

/// 会话内搜索的类型过滤。
///
/// 图片/视频/文件直接下推给本地库（`content_type IN (...)`）；
/// 链接没有独立类型，先取文本类消息，再按内容里是否含 http(s) 过滤。
enum ChatMessageSearchFilter { all, media, files, links }

extension ChatMessageSearchFilterX on ChatMessageSearchFilter {
  String get label => switch (this) {
    ChatMessageSearchFilter.all => '全部',
    ChatMessageSearchFilter.media => '图片视频',
    ChatMessageSearchFilter.files => '文件',
    ChatMessageSearchFilter.links => '链接',
  };

  String get hint => switch (this) {
    ChatMessageSearchFilter.all => '搜索聊天记录',
    ChatMessageSearchFilter.media => '搜索图片或视频',
    ChatMessageSearchFilter.files => '搜索文件',
    ChatMessageSearchFilter.links => '搜索链接',
  };

  /// 下推给本地库的 content_type 白名单；空表示不过滤。
  List<int> get messageTypes => switch (this) {
    ChatMessageSearchFilter.all => const [],
    ChatMessageSearchFilter.media => const [102, 104],
    ChatMessageSearchFilter.files => const [105],
    // 文本类：普通文本 / @文本 / 引用、合并、名片等文本承载类型
    ChatMessageSearchFilter.links => const [101, 106, 113, 114, 115, 117, 118],
  };

  /// 类型过滤是否还需要在 Dart 侧二次判断。
  bool get needsLocalMatch => this == ChatMessageSearchFilter.links;

  bool matches(MessageSearchResult result) {
    if (this == ChatMessageSearchFilter.all) return true;
    if (!messageTypes.contains(result.contentType)) return false;
    if (this == ChatMessageSearchFilter.links) {
      return looksLikeLink(result.content);
    }
    return true;
  }
}

final RegExp _linkPattern = RegExp(r'https?://[^\s"\\]+', caseSensitive: false);

/// 消息内容里是否包含 http(s) 链接（含 JSON 转义后的内容）。
bool looksLikeLink(String content) => _linkPattern.hasMatch(content);
