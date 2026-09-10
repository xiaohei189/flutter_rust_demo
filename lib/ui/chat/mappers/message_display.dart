import 'message_media.dart';
import 'message_parsed.dart' show parsedContentOf;
import 'message_system_text.dart' show readableSystemMessage;

import 'package:intl/intl.dart';

export 'message_converters.dart';
export 'message_media.dart';
export 'message_search_display.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/message.dart'
    show MessageType, MessageSendStatus, messageTypeFromContentType;

final DateFormat _messageHourMinuteFormat = DateFormat('HH:mm');
final DateFormat _messageMonthDayFormat = DateFormat('MM月dd日');
final DateFormat _messageFullDateFormat = DateFormat('yyyy年MM月dd日');

/// 气泡时间文案缓存：值只随「本地日期」变化，跨天时整体失效。
final Map<int, String> _messageTimeTextCache = <int, String>{};
int _messageTimeTextCacheDayKey = -1;
const int _messageTimeTextCacheLimit = 2000;

/// 气泡时间文案：今天=HH:mm，昨天=昨天 HH:mm，一周内=周X HH:mm，
/// 同年=MM月dd日 HH:mm，往年=yyyy年MM月dd日 HH:mm。
///
/// 结果按「发送时间」缓存到当天结束（[now] 仅用于测试注入）：
/// 消息列表在收到新消息、多选、上传进度等场景会重建可见项，
/// 缓存可避免每条气泡重复做 DateTime 计算与 DateFormat 格式化。
String formatMessageTime(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final dayKey = current.year * 10000 + current.month * 100 + current.day;
  if (dayKey != _messageTimeTextCacheDayKey) {
    _messageTimeTextCache.clear();
    _messageTimeTextCacheDayKey = dayKey;
  }

  final cacheKey = dateTime.millisecondsSinceEpoch;
  final cached = _messageTimeTextCache[cacheKey];
  if (cached != null) return cached;

  final text = _computeMessageTimeText(dateTime, current);
  if (_messageTimeTextCache.length >= _messageTimeTextCacheLimit) {
    _messageTimeTextCache.clear();
  }
  _messageTimeTextCache[cacheKey] = text;
  return text;
}

String _computeMessageTimeText(DateTime dateTime, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final diff = today.difference(messageDay).inDays;
  final timeText = _messageHourMinuteFormat.format(dateTime);

  if (diff == 0) return timeText;
  if (diff == 1) return '昨天 $timeText';
  if (diff < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${weekdays[dateTime.weekday - 1]} $timeText';
  }
  if (now.year == dateTime.year) {
    return '${_messageMonthDayFormat.format(dateTime)} $timeText';
  }
  return '${_messageFullDateFormat.format(dateTime)} $timeText';
}

/// 给 Rust 生成的 MessageInfo 添加 UI 便利方法
extension ChatMessageExt on ChatMessage {
  /// 消息类型枚举
  MessageType get messageType => messageTypeFromContentType(contentType);

  /// 解析后的 content JSON（带缓存，避免多个展示 getter 重复解析）
  Map<String, dynamic> get parsedContent => parsedContentOf(this);

  /// 显示用的文本内容
  String get displayText {
    final json = parsedContent;
    return switch (messageType) {
      MessageType.text => json['content'] as String? ?? content,
      MessageType.advancedText => json['content'] as String? ?? '',
      MessageType.markdown => json['content'] as String? ?? '',
      MessageType.quote => json['text'] as String? ?? '',
      MessageType.at => json['text'] as String? ?? '',
      MessageType.merge => '[聊天记录] $mergeMessageCount条消息',
      MessageType.system => _systemDisplayText(json),
      _ => content,
    };
  }

  String _systemDisplayText(Map<String, dynamic> json) =>
      readableSystemMessage(json, content);

  /// 发送时间 DateTime
  DateTime get sendDateTime {
    final t = sendTime.toInt();
    return t > 0
        ? DateTime.fromMillisecondsSinceEpoch(t)
        : DateTime.fromMillisecondsSinceEpoch(createTime.toInt());
  }

  /// 消息发送状态（仅自己发的消息有效）
  MessageSendStatus? get messageSendStatus =>
      MessageSendStatus.fromValue(status);
}

/// 给 Rust 生成的 LocalChatLog 添加 UI 展示文本
