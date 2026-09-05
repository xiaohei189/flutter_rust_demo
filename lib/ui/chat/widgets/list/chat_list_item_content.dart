import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/conversation_draft.dart';
import '../../../../domain/models/user.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../utils/conversation_display.dart';
import '../../view_models/chat_list_view_model.dart';

/// 会话列表项内容行：头像角标、名称/标签/时间、消息预览。
class ChatListItemContent extends StatelessWidget {
  const ChatListItemContent({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.currentUserId,
    this.cachedUserProfile,
    this.previewText,
    this.timeText,
    this.isSelectionMode = false,
    this.isOnline,
    this.typingText,
    this.hasSendFailure = false,
    this.onRetrySend,
    this.contentHorizontalPadding,
  });

  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<Rect> onLongPress;
  final String? currentUserId;
  final UserProfile? cachedUserProfile;
  final String? previewText;
  final String? timeText;

  /// 多选管理模式：显示复选框，点击由外层处理。
  final bool isSelectionMode;

  /// 单聊对方是否在线（null 表示未知，不显示绿点）。
  final bool? isOnline;

  /// 正在输入预览文案（非空时替换消息预览）。
  final String? typingText;

  /// 最近一条消息发送失败。
  final bool hasSendFailure;
  final VoidCallback? onRetrySend;
  final double? contentHorizontalPadding;

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(int? timeMs) {
    if (timeMs == null || timeMs <= 0) return '';
    final time = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final now = DateTime.now();
    // 当天显示时间；否则按设计稿以日期格式展示
    if (_isSameDay(time, now)) {
      return DateFormat('HH:mm').format(time);
    }
    if (time.year == now.year) {
      return DateFormat('M月d日').format(time);
    }
    return DateFormat('yyyy年M月d日').format(time);
  }

  String get _conversationDisplayName {
    if (conversation.showName.isNotEmpty) return conversation.showName;
    final cid = conversation.conversationId;
    switch (conversation.conversationType) {
      case 1:
        if (conversation.userId.isNotEmpty &&
            !_isConversationIdPrefix(conversation.userId)) {
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
        if (conversation.groupId.isNotEmpty &&
            !_isConversationIdPrefix(conversation.groupId)) {
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
    String userId;
    String displayName;
    String? avatarUrl;

    if (conversation.conversationType == 1) {
      // 单聊：展示对方的信息
      if (conversation.userId.isNotEmpty &&
          conversation.userId != currentUserId) {
        userId = conversation.userId;
        displayName =
            cachedUserProfile?.nickname ??
            (conversation.showName.isNotEmpty
                ? conversation.showName
                : '用户 $userId');
        avatarUrl = cachedUserProfile?.faceUrl;
      } else if (currentUserId != null &&
          conversation.conversationId.startsWith('si_')) {
        // 从会话ID中解析对方ID
        final parts = conversation.conversationId.substring(3).split('_');
        if (parts.length >= 2) {
          final otherId = parts[0] == currentUserId ? parts[1] : parts[0];
          userId = otherId;
          displayName =
              cachedUserProfile?.nickname ??
              (conversation.showName.isNotEmpty
                  ? conversation.showName
                  : '用户 $otherId');
          avatarUrl = cachedUserProfile?.faceUrl;
        } else {
          userId = conversation.userId.isNotEmpty
              ? conversation.userId
              : conversation.conversationId;
          displayName = conversation.showName.isNotEmpty
              ? conversation.showName
              : '未知用户';
          avatarUrl = conversation.faceUrl.isNotEmpty
              ? conversation.faceUrl
              : null;
        }
      } else {
        userId = conversation.userId.isNotEmpty
            ? conversation.userId
            : conversation.conversationId;
        displayName = conversation.showName.isNotEmpty
            ? conversation.showName
            : '未知用户';
        avatarUrl = conversation.faceUrl.isNotEmpty
            ? conversation.faceUrl
            : null;
      }
    } else {
      // 群聊或其他类型：展示群组信息
      userId = conversation.groupId.isNotEmpty
          ? conversation.groupId
          : conversation.conversationId;
      displayName = conversation.showName.isNotEmpty
          ? conversation.showName
          : _conversationDisplayName;
      avatarUrl = conversation.faceUrl.isNotEmpty
          ? conversation.faceUrl
          : cachedUserProfile?.faceUrl;
    }

    // 优先使用缓存的用户资料头像，其次使用会话头像
    final finalAvatar = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : null;

    return User(
      id: userId,
      name: displayName,
      avatar: finalAvatar,
      status: null,
    );
  }

  /// 展示时间：取草稿时间和最新消息时间中较新的
  int get _displayTime {
    final draftTime = conversation.draftTextTime;
    final msgTime = conversation.latestMsgSendTime;
    if (draftTime > msgTime) return draftTime;
    return msgTime;
  }

  String get _contentPreview {
    if (conversation.draftText.isNotEmpty) {
      final draft = ConversationDraft.textOf(conversation.draftText);
      // 非 JSON 纯文本直接展示；JSON 但无有效 text key 时回退最新消息。
      if (draft != null) return draft;
    }
    final preview = previewText ?? latestMessagePreview(conversation.latestMsg);
    return preview;
  }

  bool get _hasDraft => conversation.draftText.isNotEmpty;

  /// 免打扰：recvMsgOpt 1=接收但不通知
  bool get _isMuted => conversation.recvMsgOpt == 1;

  bool get _isGroup =>
      conversation.conversationType == 2 || conversation.conversationType == 3;

  /// 占位标签：无 external/bot/agent 数据，先用会话 ID 稳定伪随机分配一个，
  /// 用于对齐设计稿的「外部/智能体/机器人」文字胶囊。
  static const List<String> _placeholderTagNames = ['外部', '智能体', '机器人'];

  static const Map<String, Color> _placeholderTagColors = {
    // 从飞书参考图采样（略取饱和值）。
    '外部': Color(0xFF2D6BE0),
    '智能体': Color(0xFF7A3BE8),
    '机器人': Color(0xFFE8960C),
  };

  String? _placeholderTagName() {
    if (conversation.conversationId.isEmpty) return null;
    var h = 0;
    for (final code in conversation.conversationId.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    // 约 1/3 不展示，其余稳定落到某个标签上，避免每次刷新漂移。
    if (h % 3 == 0) return null;
    return _placeholderTagNames[h % _placeholderTagNames.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final user = _getUser();
    final isPinned = conversation.isPinned;

    return Material(
      color: isPinned
          ? colors.surfaceMuted
          : (isSelected
                ? colors.primary.withValues(alpha: 0.06)
                : colors.surface),
      child: GestureDetector(
        onLongPressStart: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.attached) {
            onLongPress(box.localToGlobal(Offset.zero) & box.size);
          } else {
            onLongPress(Rect.fromLTWH(d.globalPosition.dx, d.globalPosition.dy, 0, 0));
          }
        },
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: contentHorizontalPadding ??
                  (isSelectionMode ? 8 : 16),
            ),
            child: Row(
            children: [
              if (isSelectionMode) ...[
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              // 头像（在线绿点 / 群头像），未读仅以时间蓝色标识，不叠加数字角标
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_isGroup)
                    _GroupAvatar(
                      conversation: conversation,
                      radius: kConversationAvatarRadius,
                    )
                  else
                    UserAvatar(user: user, radius: kConversationAvatarRadius),
                  if (isOnline == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // 内容区
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：名称 + 标签（紧跟标题） + 时间（固定最右）
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ..._buildTags(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 时间：自然宽度，位于行最右
                        Text(
                          timeText ?? _formatTime(_displayTime),
                          style: TextStyle(
                            fontSize: 12,
                            // 对齐设计稿：未读不以日期变色，统一灰色，未读态走角标/筛选。
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 第二行：消息预览
                    _buildPreviewLine(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }


  /// 标签收敛：最多展示 2 个，优先级 不在群内 > @我 > 通知。
  List<Widget> _buildTags(BuildContext context) {
    final colors = context.appColors;
    final tags = <Widget>[];
    // 占位：无 external/bot/agent 数据，先展示设计稿同款文字胶囊。
    final placeholder = _placeholderTagName();
    if (placeholder != null) {
      tags.add(
        _TagLabel(
          text: placeholder,
          color: _placeholderTagColors[placeholder]!,
        ),
      );
    }
    if (conversation.isNotInGroup) {
      tags.add(_TagLabel(text: '不在群内', color: colors.danger));
    }
    if (ChatListViewModel.isAtMeConversation(conversation) && tags.length < 2) {
      tags.add(_TagLabel(text: '@我', color: colors.primary));
    }
    if (conversation.conversationType == 4 && tags.length < 2) {
      tags.add(_TagLabel(text: '通知', color: colors.textSecondary));
    }
    if (_isMuted && tags.length < 2) {
      tags.add(
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(
            Icons.notifications_off_outlined,
            size: 14,
            color: colors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    return tags;
  }

  Widget _buildPreviewLine(BuildContext context) {
    final colors = context.appColors;
    if (typingText != null && typingText!.isNotEmpty) {
      return Text(
        typingText!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: colors.primary),
      );
    }
    if (hasSendFailure) {
      return GestureDetector(
        onTap: onRetrySend,
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 14, color: colors.danger),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '发送失败，点击重试',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.danger),
              ),
            ),
          ],
        ),
      );
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(fontSize: 15, color: colors.textSecondary),
        children: [
          if (_hasDraft)
            TextSpan(
              text: '[草稿] ',
              style: TextStyle(color: colors.warning),
            ),
          TextSpan(text: _contentPreview),
        ],
      ),
    );
  }
}

/// 群聊头像：统一圆形 + 群组图标（群头像由服务端 faceUrl 提供时优先展示；
/// 无头像时用与单聊一致的彩色圆底，保证列表头像视觉统一）。
class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.conversation, required this.radius});

  final Conversation conversation;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final url = conversation.faceUrl;
    if (url.isNotEmpty) {
      return UserAvatar(
        user: User(id: conversation.groupId, name: '', avatar: url),
        radius: radius,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: kNameAvatarBackground,
      child: Icon(Icons.group, size: radius * 1.2, color: colors.onPrimary),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
