import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import 'unread_count_view.dart';
import 'user_avatar.dart';

/// 会话列表项颜色与 openim-flutter-demo 对齐
const _colorName = Color(0xFF0C1C33);
const _colorSub = Color(0xFF8E9AB0);

/// 从 map 中取 key（支持 camelCase / snake_case）
T? _getKey<T>(Map<String, dynamic> map, String camel, String snake) {
  if (map.containsKey(camel) && map[camel] != null) return map[camel] as T?;
  if (map.containsKey(snake) && map[snake] != null) return map[snake] as T?;
  return null;
}

/// 从 content 中解析出可读字符串（可能是 String / List<int> bytes / Map）
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
  }
  return content.toString().trim();
}

/// 从 latestMsg JSON 中解析出用于列表展示的文案（仅展示消息内容，不展示整段 JSON）
String latestMessagePreview(String latestMsgJson) {
  if (latestMsgJson.isEmpty) return '暂无消息';
  final trimmed = latestMsgJson.trim();
  if (trimmed.isEmpty) return '暂无消息';
  // 非 JSON 时（例如纯文本）直接展示
  if (!trimmed.startsWith('{')) {
    return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
  }
  try {
    final map = jsonDecode(latestMsgJson) as Map<String, dynamic>?;
    if (map == null) return '暂无消息';

    final contentType = _getKey<int>(map, 'contentType', 'content_type') ?? 0;
    final senderNickname = _getKey<String>(map, 'senderNickname', 'sender_nickname') ?? '';
    final content = map['content'];
    final textElem = _getKey<Map<String, dynamic>>(map, 'textElem', 'text_elem');

    String body;
    switch (contentType) {
      case 101: // TEXT
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
    return latestMsgJson.length > 60 ? '${latestMsgJson.substring(0, 60)}…' : latestMsgJson;
  }
}

/// 聊天列表项组件（参考会话列表效果：红点未读、草稿、时间格式、选中高亮）
class ChatListItem extends StatelessWidget {
  final im_conv.LocalConversation conversation;
  final VoidCallback onTap;
  /// 是否为当前选中项（高亮背景）
  final bool isSelected;
  /// 当前登录用户 ID，用于从单聊 conversationId(si_uid1_uid2) 中解析出对方显示名
  final String? currentUserId;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
    this.currentUserId,
  });

  /// 时间展示：与 openim IMUtils.getChatTimeline 一致（今天 HH:mm、昨天、周x、今年 M月d日、更早 yyyy年）
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isSameWeek(DateTime a, DateTime b) {
    final start = b.subtract(Duration(days: b.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return !a.isBefore(start.subtract(const Duration(days: 1))) &&
        !a.isAfter(end.add(const Duration(days: 1)));
  }

  static const _weekdayZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  String _formatTime(PlatformInt64? timeMs) {
    if (timeMs == null || timeMs.toInt() <= 0) return '';

    final time = DateTime.fromMillisecondsSinceEpoch(timeMs.toInt());
    final now = DateTime.now();
    const formatToday = 'HH:mm';

    if (_isSameDay(time, now)) {
      return DateFormat(formatToday).format(time);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(time, yesterday)) {
      return '昨天 ${DateFormat(formatToday).format(time)}';
    }
    if (_isSameWeek(time, now)) {
      return '${_weekdayZh[time.weekday - 1]} ${DateFormat(formatToday).format(time)}';
    }
    if (time.year == now.year) {
      return DateFormat('M月d日 HH:mm').format(time);
    }
    return DateFormat('yyyy年M月d日 HH:mm').format(time);
  }

  /// 会话展示名称：优先 showName；否则避免直接展示 si_/sg_ 原始 ID，解析为「用户 XXX」/「群聊 XXX」
  String get _conversationDisplayName {
    if (conversation.showName.isNotEmpty) return conversation.showName;
    final cid = conversation.conversationId;
    switch (conversation.conversationType) {
      case 1: // 单聊：conversationId 格式 si_uid1_uid2，取「对方」ID 显示
        if (conversation.userId.isNotEmpty && !_isConversationIdPrefix(conversation.userId)) {
          return conversation.userId;
        }
        if (cid.startsWith('si_')) {
          final parts = cid.substring(3).split('_');
          if (parts.length >= 2) {
            final other = currentUserId != null && parts[0] == currentUserId
                ? parts[1]
                : parts[0];
            return other.isNotEmpty ? '用户 $other' : '未知用户';
          }
        }
        return '未知用户';
      case 2:
      case 3: // 群聊：conversationId 格式 sg_groupId
        if (conversation.groupId.isNotEmpty && !_isConversationIdPrefix(conversation.groupId)) {
          return conversation.groupId;
        }
        if (cid.startsWith('sg_')) {
          final groupId = cid.substring(3);
          return groupId.isNotEmpty ? '群聊 $groupId' : '未知群组';
        }
        return '未知群组';
      case 4:
        return '通知';
      default:
        return _isConversationIdPrefix(cid) ? '会话' : cid;
    }
  }

  static bool _isConversationIdPrefix(String s) =>
      s.startsWith('si_') || s.startsWith('sg_') || s.startsWith('sn_');

  User _getUser() {
    final userId = conversation.userId.isNotEmpty
        ? conversation.userId
        : conversation.groupId;
    return User(
      id: userId,
      name: _conversationDisplayName,
      avatar: conversation.faceUrl.isNotEmpty ? conversation.faceUrl : null,
      status: null,
    );
  }

  /// 副标题主文案：与 openim getContent 一致。草稿支持 JSON {"text":"..."}，否则 latestMsg 预览；无消息时提示「点击发消息」
  String get _contentPreview {
    if (conversation.draftText.isNotEmpty) {
      try {
        final map = jsonDecode(conversation.draftText) as Map<String, dynamic>?;
        final text = map?['text'] as String?;
        if (text != null && text.isNotEmpty) return text;
      } catch (_) {}
      return conversation.draftText;
    }
    final preview = latestMessagePreview(conversation.latestMsg);
    return preview == '暂无消息' ? '点击发消息' : preview;
  }

  /// 未读条数前缀「[n条] 」；无未读返回空
  String get _unreadPrefix {
    final n = conversation.unreadCount;
    return n > 0 ? '[$n条] ' : '';
  }

  bool get _hasDraft => conversation.draftText.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final user = _getUser();
    final latestMsgTime = conversation.latestMsgSendTime;
    final unread = conversation.unreadCount;

    return Material(
      color: isSelected ? Colors.blue.withOpacity(0.08) : null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(user: user, radius: 24),
                  if (conversation.isPinned)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.push_pin, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              color: _colorName,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(latestMsgTime),
                          style: const TextStyle(fontSize: 12, color: _colorSub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: _colorSub),
                              children: [
                                if (_hasDraft)
                                  const TextSpan(
                                    text: '[草稿] ',
                                    style: TextStyle(color: Color(0xFF0089FF), fontSize: 14),
                                  )
                                else if (_unreadPrefix.isNotEmpty)
                                  TextSpan(text: _unreadPrefix),
                                TextSpan(text: _contentPreview),
                              ],
                            ),
                          ),
                        ),
                        UnreadCountView(count: unread),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
