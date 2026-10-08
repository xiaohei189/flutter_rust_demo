import 'package:lpinyin/lpinyin.dart';

/// 通讯录索引：按姓名首字母分组（中文取拼音首字母）+ 内嵌搜索匹配。
///
/// 全是纯函数，方便单测；页面只负责渲染与跳转。
class ContactIndex {
  const ContactIndex._();

  /// 非 A–Z 开头的名字（数字、符号、Emoji…）统一归到「#」，排在最后。
  static const String otherBucket = '#';

  /// 姓名首字母（A–Z）；取不到（空名/非中英文字符）时返回 [otherBucket]。
  ///
  /// 取的是**展示名首个字符**的拼音首字母（对齐飞书：张伟 → Z，李娜 → L，
  /// xiaoming → X）。
  static String initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return otherBucket;
    // 用 runes 取首字符，避免把非 BMP 字符（emoji）切坏
    final first = String.fromCharCode(trimmed.runes.first);
    final code = first.codeUnitAt(0);
    final isAsciiLetter =
        (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
    final candidate = isAsciiLetter
        ? first.toUpperCase()
        : _shortPinyin(first).toUpperCase();
    if (candidate.isEmpty) return otherBucket;
    final initial = candidate.codeUnitAt(0);
    if (initial >= 0x41 && initial <= 0x5A) return candidate[0];
    return otherBucket;
  }

  /// 按首字母分组：A→Z 升序，[otherBucket] 排最后。
  static Map<String, List<T>> group<T>(
    List<T> items,
    String Function(T) nameOf,
  ) {
    final grouped = <String, List<T>>{};
    for (final item in items) {
      grouped.putIfAbsent(initialOf(nameOf(item)), () => <T>[]).add(item);
    }
    final letters = grouped.keys.toList()
      ..sort((a, b) {
        if (a == otherBucket) return 1;
        if (b == otherBucket) return -1;
        return a.compareTo(b);
      });
    return {for (final letter in letters) letter: grouped[letter]!};
  }

  /// 内嵌搜索匹配：姓名/昵称/ID 命中，或拼音（首字母 "zw"、全拼 "zhang"）命中。
  static bool matches({
    required String query,
    required String displayName,
    String nickname = '',
    String userId = '',
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (displayName.toLowerCase().contains(needle) ||
        nickname.toLowerCase().contains(needle) ||
        userId.toLowerCase().contains(needle)) {
      return true;
    }
    if (_shortPinyin(displayName).toLowerCase().contains(needle)) return true;
    final full = _fullPinyin(displayName);
    return full.contains(needle);
  }

  /// 拼音首字母串（张伟 → zw）；转换失败时退化为原串，保证不抛异常。
  static String _shortPinyin(String text) {
    try {
      return PinyinHelper.getShortPinyin(text);
    } catch (_) {
      return text;
    }
  }

  /// 无分隔符全拼（张伟 → zhangwei），用于「zhang」这类输入。
  static String _fullPinyin(String text) {
    try {
      return PinyinHelper.getPinyin(text, separator: '').toLowerCase();
    } catch (_) {
      return text.toLowerCase();
    }
  }
}
