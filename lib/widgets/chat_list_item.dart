import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import 'unread_count_view.dart';
import 'user_avatar.dart';

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
    return latestMsgJson.length > 60 ? '${latestMsgJson.substring(0, 60)}…' : latestMsgJson;
  }
}

/// 会话列表项：头像、标题、预览、时间、未读红点、静音图标；草稿红色/橙色；长按菜单、左滑删除
class ChatListItem extends StatelessWidget {
  final im_conv.LocalConversation conversation;
  final VoidCallback onTap;
  final bool isSelected;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onPinToggle;
  final VoidCallback? onMarkRead;
  /// 列表索引，用于 Dismissible 的 key，避免删除时重建冲突
  final int? itemIndex;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
    this.currentUserId,
    this.onDelete,
    this.onPinToggle,
    this.onMarkRead,
    this.itemIndex,
  });

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
      return '昨天';
    }
    if (_isSameWeek(time, now)) {
      return _weekdayZh[time.weekday - 1];
    }
    if (time.year == now.year) {
      return DateFormat('M/d').format(time);
    }
    return DateFormat('yyyy/M/d').format(time);
  }

  String get _conversationDisplayName {
    if (conversation.showName.isNotEmpty) return conversation.showName;
    final cid = conversation.conversationId;
    switch (conversation.conversationType) {
      case 1:
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
      case 3:
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

  String get _unreadPrefix {
    final n = conversation.unreadCount;
    return n > 0 ? '[$n条] ' : '';
  }

  bool get _hasDraft => conversation.draftText.isNotEmpty;
  /// 免打扰：recvMsgOpt 1=接收但不通知
  bool get _isMuted => conversation.recvMsgOpt == 1;

  Widget _buildContent(BuildContext context) {
    final user = _getUser();
    final unread = conversation.unreadCount;

    return Material(
      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showLongPressMenu(context),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(user: user, radius: 26),
                  if (conversation.isPinned)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.draftOrange,
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
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(conversation.latestMsgSendTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                              children: [
                                if (_hasDraft)
                                  const TextSpan(
                                    text: '[草稿] ',
                                    style: TextStyle(
                                      color: AppTheme.draftOrange,
                                      fontSize: 14,
                                    ),
                                  )
                                else if (_unreadPrefix.isNotEmpty)
                                  TextSpan(text: _unreadPrefix),
                                TextSpan(text: _contentPreview),
                              ],
                            ),
                          ),
                        ),
                        if (_isMuted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              size: 16,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
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

  void _showLongPressMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(conversation.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.pop(ctx);
                onPinToggle?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.done_all_outlined),
              title: const Text('标为已读'),
              onTap: () {
                Navigator.pop(ctx);
                onMarkRead?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.unreadRed),
              title: const Text('删除', style: TextStyle(color: AppTheme.unreadRed)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onDelete != null) {
      return Dismissible(
        key: ValueKey<String>(
          '${conversation.conversationId}_${itemIndex ?? 0}',
        ),
        direction: DismissDirection.endToStart,
        background: Container(
          color: AppTheme.unreadRed,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        onDismissed: (_) => onDelete!(),
        child: _buildContent(context),
      );
    }
    return _buildContent(context);
  }
}
