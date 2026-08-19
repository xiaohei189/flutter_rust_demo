import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../domain/extensions/message_ext.dart';
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../core/theme/app_theme.dart';

class TextMessageContent extends StatelessWidget {
  const TextMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    final color = isFromMe
        ? context.appColors.onPrimary
        : context.appColors.bubbleOtherText;
    return Text(
      message.displayText,
      style: TextStyle(color: color, fontSize: 16),
    );
  }
}

class AtMessageContent extends StatelessWidget {
  const AtMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    final color = isFromMe
        ? context.appColors.onPrimary
        : context.appColors.bubbleOtherText;
    return Text(
      message.displayText,
      style: TextStyle(color: color, fontSize: 16),
    );
  }
}

class MarkdownMessageContent extends StatelessWidget {
  const MarkdownMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    final textColor = isFromMe
        ? context.appColors.onPrimary
        : context.appColors.bubbleOtherText;
    final linkColor = isFromMe
        ? context.appColors.onPrimary.withValues(alpha: 0.7)
        : context.appColors.primary;
    final codeBgColor = isFromMe
        ? context.appColors.onPrimary.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.06);

    return MarkdownBody(
      data: message.displayText,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
        h1: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h4: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h5: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        h6: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
        code: TextStyle(
          color: textColor,
          fontSize: 14,
          fontFamily: 'monospace',
          backgroundColor: codeBgColor,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(8),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: linkColor.withValues(alpha: 0.5), width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        a: TextStyle(color: linkColor, decoration: TextDecoration.underline),
        listBullet: TextStyle(color: textColor, fontSize: 16),
        tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        tableBody: TextStyle(color: textColor, fontSize: 14),
        tableBorder: TableBorder.all(
          color: textColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
    );
  }
}

class FaceMessageContent extends StatelessWidget {
  const FaceMessageContent({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message.displayText.isNotEmpty ? message.displayText : '😀',
      style: const TextStyle(fontSize: 48),
    );
  }
}

class SystemMessageContent extends StatelessWidget {
  const SystemMessageContent({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.appColors.textSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message.displayText,
        style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}
