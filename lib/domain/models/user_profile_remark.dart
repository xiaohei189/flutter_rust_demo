import 'dart:convert';

/// 用户资料 `remark` 字段中的本地扩展（别名/签名），JSON 编解码。
///
/// 服务端 remark 可能同时包含别名与签名，约定存为 `{"alias": "...", "signature": "..."}`。
class UserProfileRemark {
  final String alias;
  final String signature;

  const UserProfileRemark({this.alias = '', this.signature = ''});

  static const empty = UserProfileRemark();

  /// 从 remark 原始值解析别名与签名；为空或非法 JSON 时返回空值。
  factory UserProfileRemark.parse(String? rawEx) {
    if (rawEx == null || rawEx.trim().isEmpty) return empty;
    try {
      final decoded = jsonDecode(rawEx);
      if (decoded is Map<String, dynamic>) {
        return UserProfileRemark(
          alias: (decoded['alias'] as String?)?.trim() ?? '',
          signature: (decoded['signature'] as String?)?.trim() ?? '',
        );
      }
    } catch (_) {}
    return empty;
  }

  /// 构建 remark：在现有值基础上更新别名/签名，保留其他 key。
  static String buildEx({
    required String currentEx,
    String? alias,
    String? signature,
  }) {
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(currentEx);
      map = decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
    if (alias != null) map['alias'] = alias;
    if (signature != null) map['signature'] = signature;
    return jsonEncode(map);
  }
}
