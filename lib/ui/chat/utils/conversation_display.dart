import 'dart:convert';

import 'package:intl/intl.dart';

T? _getKey<T>(Map<String, dynamic> map, String camel, String snake) {
  if (map.containsKey(camel) && map[camel] != null) return map[camel] as T?;
  if (map.containsKey(snake) && map[snake] != null) return map[snake] as T?;
  return null;
}

String _contentToDisplay(dynamic content) {
  if (content == null) return '';
  if (content is String) return content.trim();
  if (content is List) {
    try {
      return utf8.decode(content.cast<int>()).trim();
    } catch (_) {
      return '';
    }
  }
  if (content is Map<String, dynamic>) {
    final text = content['text'];
    if (text is Map<String, dynamic> && text['content'] != null) {
      return text['content'].toString().trim();
    }
    if (content['content'] != null) return content['content'].toString().trim();
    for (final value in content.values) {
      if (value is String && value.isNotEmpty) return value;
    }
  }
  return content.toString().trim();
}

/// 从 latestMsg JSON 中解析出用于列表展示的文案（仅展示消息内容，不展示整段 JSON）。
String latestMessagePreview(String latestMsgJson) {
  if (latestMsgJson.isEmpty) return '暂无消息';
  final trimmed = latestMsgJson.trim();
  if (trimmed.isEmpty) return '暂无消息';
  if (!trimmed.startsWith('{')) {
    return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
  }
  try {
    final map = jsonDecode(latestMsgJson) as Map<String, dynamic>?;
    if (map == null) return '暂无消息';

    final contentType = _getKey<int>(map, 'contentType', 'content_type') ?? 0;
    final senderNickname =
        _getKey<String>(map, 'senderNickname', 'sender_nickname') ?? '';
    final content = map['content'];
    final textElem = _getKey<Map<String, dynamic>>(
      map,
      'textElem',
      'text_elem',
    );

    String body;
    switch (contentType) {
      case 101:
        body = '';
        if (textElem != null) {
          final c = textElem['content'];
          if (c != null) body = _contentToDisplay(c);
        }
        if (body.isEmpty && content != null) body = _contentToDisplay(content);
        if (body.isEmpty) body = '文本';
        break;
      case 102:
        body = '[图片]';
        break;
      case 103:
        body = '[语音]';
        break;
      case 104:
        body = '[视频]';
        break;
      case 105:
        body = '[文件]';
        break;
      case 106:
        body = '[@消息]';
        break;
      case 107:
        body = '[引用]';
        break;
      case 108:
        body = '[位置]';
        break;
      case 109:
        body = '[自定义]';
        break;
      case 110:
        body = '[撤回]';
        break;
      default:
        if (contentType > 0) {
          body = '[$contentType]';
        } else {
          body = _contentToDisplay(content);
          if (body.isEmpty && textElem != null) {
            body = _contentToDisplay(textElem['content']);
          }
          if (body.isEmpty) body = '暂无消息';
        }
    }

    if (body.isEmpty) body = '暂无消息';
    if (senderNickname.isNotEmpty && body != '暂无消息') {
      return '$senderNickname: $body';
    }
    return body;
  } catch (_) {
    return latestMsgJson.length > 60
        ? '${latestMsgJson.substring(0, 60)}…'
        : latestMsgJson;
  }
}

/// 会话列表时间：今天显示时分，其余按昨天/周/日期降级。
String formatConversationTime(int? timeMs) {
  if (timeMs == null || timeMs <= 0) return '';
  final time = DateTime.fromMillisecondsSinceEpoch(timeMs);
  final now = DateTime.now();
  if (_isSameDay(time, now)) {
    return DateFormat('HH:mm').format(time);
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(time, yesterday)) {
    return '昨天';
  }
  if (_isSameWeek(time, now)) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[time.weekday - 1];
  }
  if (time.year == now.year) {
    return DateFormat('M/d').format(time);
  }
  return DateFormat('yyyy/M/d').format(time);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isSameWeek(DateTime a, DateTime b) {
  final start = b.subtract(Duration(days: b.weekday - 1));
  final end = start.add(const Duration(days: 6));
  return !a.isBefore(start.subtract(const Duration(days: 1))) &&
      !a.isAfter(end.add(const Duration(days: 1)));
}
