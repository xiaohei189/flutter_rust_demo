import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
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

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
  });

  /// 时间展示：当天仅时间，否则「年月日 时:分」
  String _formatTime(PlatformInt64? timeMs) {
    if (timeMs == null || timeMs.toInt() <= 0) return '';

    final time = DateTime.fromMillisecondsSinceEpoch(timeMs.toInt());
    final now = DateTime.now();
    final sameDay = time.year == now.year && time.month == now.month && time.day == now.day;

    if (sameDay) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat('yyyy年M月d日 HH:mm').format(time);
  }

  /// 会话展示名称：优先 showName，否则按会话类型显示「用户/群聊 ID」或会话 ID
  String get _conversationDisplayName {
    if (conversation.showName.isNotEmpty) return conversation.showName;
    switch (conversation.conversationType) {
      case 1: // 单聊
        return conversation.userId.isNotEmpty ? '用户 ${conversation.userId}' : conversation.conversationId;
      case 2:
      case 3: // 普通群聊 / 超级群聊
        return conversation.groupId.isNotEmpty ? '群聊 ${conversation.groupId}' : conversation.conversationId;
      case 4: // 通知会话
        return '通知';
      default:
        return conversation.conversationId;
    }
  }

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

  /// 副标题：有草稿显示「[草稿] 内容」，否则解析 latestMsg JSON 显示消息内容预览
  Widget _buildSubtitle() {
    final hasDraft = conversation.draftText.isNotEmpty;
    final String content = hasDraft ? conversation.draftText : latestMessagePreview(conversation.latestMsg);

    if (hasDraft) {
      return Row(
        children: [
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                children: [
                  TextSpan(
                    text: '[草稿] ',
                    style: TextStyle(color: Colors.teal[700], fontSize: 14),
                  ),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      content,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Colors.grey[700], fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _getUser();
    final latestMsgTime = conversation.latestMsgSendTime;
    final hasUnread = conversation.unreadCount > 0;

    return Material(
      color: isSelected ? Colors.blue.withOpacity(0.08) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            UserAvatar(user: user, radius: 28),
            if (conversation.isPinned)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.push_pin,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 未读红点（紧挨会话名右侧）
            if (hasUnread) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              _formatTime(latestMsgTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildSubtitle(),
        ),
        onTap: onTap,
      ),
    );
  }
}
