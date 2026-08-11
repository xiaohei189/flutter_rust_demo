import 'package:flutter/material.dart';

import '../../../../domain/extensions/message_ext.dart';
import '../../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../core/theme/app_theme.dart';

class QuoteMessagePreview extends StatelessWidget {
  const QuoteMessagePreview({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final MessageInfo message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.quoteSenderNickname.isNotEmpty)
            Text(
              message.quoteSenderNickname,
              style: TextStyle(
                color: isFromMe ? Colors.white70 : context.appColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (message.quoteReplyContent.isNotEmpty)
            Text(
              message.quoteReplyContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFromMe
                    ? Colors.white60
                    : context.appColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class QuoteMessageContent extends StatelessWidget {
  const QuoteMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final MessageInfo message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        QuoteMessagePreview(message: message, isFromMe: isFromMe),
        Text(
          message.quoteText.isNotEmpty
              ? message.quoteText
              : message.displayText,
          style: TextStyle(
            color: isFromMe ? Colors.white : context.appColors.bubbleOtherText,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
