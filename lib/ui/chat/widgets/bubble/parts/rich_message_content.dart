import 'package:flutter/material.dart';

import '../../../mappers/message_display.dart';
import '../../../../../domain/models/chat_message.dart' show ChatMessage;
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
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFromMe
            ? context.appColors.onPrimary.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
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
}
