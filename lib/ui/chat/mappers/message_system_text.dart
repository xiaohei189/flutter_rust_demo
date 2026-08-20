import 'dart:convert';

String readableSystemMessage(Map<String, dynamic> json, String fallback) {
  if (json.containsKey('revokerID') || json.containsKey('revokerNickname')) {
    final nickname = json['revokerNickname'] as String?;
    return '$nickname 撤回了一条消息';
  }
  if (json.containsKey('content')) {
    final value = json['content'];
    if (value is String && value.isNotEmpty && !value.contains('"')) {
      return value;
    }
  }
  for (final key in ['detail', 'msgTips', 'tips', 'text']) {
    final value = json[key];
    if (value is! String || value.isEmpty) continue;
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          final readable = _firstReadableMessageField(decoded);
          if (readable != null) return readable;
        }
      } catch (_) {}
    } else if (!value.contains('"')) {
      return value;
    }
  }
  if (fallback.isNotEmpty && !fallback.contains('"')) return fallback;
  return '[系统消息]';
}

String? _firstReadableMessageField(Map<String, dynamic> map) {
  for (final field in [
    'reqMsg',
    'content',
    'msgTips',
    'tips',
    'text',
    'nickname',
    'fromNickname',
    'toNickname',
    'handleMsg',
  ]) {
    final item = map[field];
    if (item is String && item.isNotEmpty) return item;
  }
  final request = map['request'];
  if (request is Map<String, dynamic>) {
    return _firstReadableMessageField(request);
  }
  return null;
}

/// 从 messageSent 事件构造 MessageInfo
