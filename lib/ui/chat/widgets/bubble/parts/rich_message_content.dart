import 'package:flutter/material.dart';

import '../../../mappers/message_display.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../../domain/models/topic.dart' show TopicShareCard;
import '../../../../core/theme/app_theme.dart';

class CardMessageContent extends StatelessWidget {
  const CardMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFromMe
            ? context.appColors.onPrimary.withValues(alpha: 0.15)
            : context.appColors.onPrimary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: message.cardFaceUrl.isNotEmpty
                    ? NetworkImage(message.cardFaceUrl)
                    : null,
                child: message.cardFaceUrl.isEmpty
                    ? Text(
                        message.cardNickname.isNotEmpty
                            ? message.cardNickname[0]
                            : '?',
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.cardNickname.isNotEmpty
                          ? message.cardNickname
                          : '未知用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isFromMe
                            ? context.appColors.onPrimary
                            : context.appColors.bubbleOtherText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      message.cardUserId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isFromMe
                            ? context.appColors.onPrimary.withValues(alpha: 0.7)
                            : context.appColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
            color: isFromMe
                ? context.appColors.onPrimary.withValues(alpha: 0.3)
                : context.appColors.surfaceMuted,
            height: 12,
          ),
          Text(
            '个人名片',
            style: TextStyle(
              color: isFromMe
                  ? context.appColors.onPrimary.withValues(alpha: 0.7)
                  : context.appColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class MergeMessageContent extends StatelessWidget {
  const MergeMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    final title = message.mergeTitle.isNotEmpty ? message.mergeTitle : '聊天记录';
    final previews = message.mergeSenderNicknames;
    final count = message.mergeMessageCount;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe
            ? context.appColors.bubbleMine
            : context.appColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isFromMe
                  ? context.appColors.onPrimary
                  : context.appColors.bubbleOtherText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 0.5,
            color: isFromMe
                ? context.appColors.onPrimary.withValues(alpha: 0.24)
                : context.appColors.surfaceMuted,
          ),
          ...previews
              .take(5)
              .map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isFromMe
                          ? context.appColors.onPrimary.withValues(alpha: 0.7)
                          : context.appColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$count条消息',
              style: TextStyle(
                color: isFromMe
                    ? context.appColors.onPrimary.withValues(alpha: 0.54)
                    : context.appColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationMessageContent extends StatelessWidget {
  const LocationMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFromMe
            ? context.appColors.onPrimary.withValues(alpha: 0.15)
            : context.appColors.onPrimary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: isFromMe
                    ? context.appColors.onPrimary
                    : context.appColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message.locationName.isNotEmpty ? message.locationName : '位置',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFromMe
                        ? context.appColors.onPrimary
                        : context.appColors.bubbleOtherText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (message.locationDesc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              message.locationDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFromMe
                    ? context.appColors.onPrimary.withValues(alpha: 0.7)
                    : context.appColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CustomMessageContent extends StatelessWidget {
  const CustomMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    final topic = message.topicShareCard;
    if (topic != null) {
      return Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: context.appColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 18,
                  color: context.appColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topic.groupName.isEmpty ? '话题群' : topic.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              topic.title.isEmpty ? '话题' : topic.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${topic.creatorName.isEmpty ? '成员' : topic.creatorName}'
              ' · ${topic.replyCount} 回复',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (topic.replies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                decoration: BoxDecoration(
                  color: context.appColors.bubbleOther,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final reply in topic.replies.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${reply.senderName}: ',
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: reply.content,
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, height: 1.35),
                        ),
                      ),
                    if (topic.replies.length > 2)
                      TextButton(
                        onPressed: () => _showTopicSnapshot(context, topic),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: context.appColors.primary,
                        ),
                        child: Text(
                          '查看全部 ${topic.replies.length} 条转发回复',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Divider(height: 1, color: context.appColors.divider),
            const SizedBox(height: 8),
            Text(
              '打开话题',
              style: TextStyle(
                color: context.appColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFromMe
            ? context.appColors.onPrimary.withValues(alpha: 0.15)
            : context.appColors.bubbleOtherText.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        message.displayText.isNotEmpty ? message.displayText : '[自定义消息]',
        style: TextStyle(
          color: isFromMe
              ? context.appColors.onPrimary
              : context.appColors.bubbleOtherText,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showTopicSnapshot(BuildContext context, TopicShareCard topic) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.groupName.isEmpty ? '话题群' : topic.groupName,
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: AppTheme.fontSizeSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topic.title.isEmpty ? '话题' : topic.title,
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    if (!topic.snapshotComplete)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '转发时收录了前 ${topic.replies.length} 条回复，原话题共 ${topic.replyCount} 条',
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: context.appColors.divider,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  itemCount: topic.replies.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 20,
                    thickness: 0.5,
                    color: context.appColors.divider,
                  ),
                  itemBuilder: (context, index) {
                    final reply = topic.replies[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(
                          avatarUrl: '',
                          fallbackName: reply.senderName,
                          radius: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply.senderName,
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reply.content,
                                style: TextStyle(
                                  color: context.appColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
