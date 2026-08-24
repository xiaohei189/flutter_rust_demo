import 'package:flutter/material.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../mappers/message_display.dart';
import '../../../../domain/models/message.dart' show MessageType;
import 'parts/media_message_content.dart';
import 'parts/quote_message_content.dart';
import 'parts/rich_message_content.dart';
import 'parts/text_message_content.dart';

/// 按消息类型分发内容组件。
Widget buildMessageContent({
  required ChatMessage message,
  required bool isFromMe,
  int? uploadProgress,
  void Function(String source)? onPlayAudio,
}) {
  return switch (message.messageType) {
    MessageType.image => ImageMessageContent(
      message: message,
      isFromMe: isFromMe,
      uploadProgress: uploadProgress,
    ),
    MessageType.video => VideoMessageContent(
      message: message,
      isFromMe: isFromMe,
      uploadProgress: uploadProgress,
    ),
    MessageType.audio => AudioMessageContent(
      message: message,
      isFromMe: isFromMe,
      onPlay: onPlayAudio,
    ),
    MessageType.file => FileMessageContent(
      message: message,
      isFromMe: isFromMe,
      uploadProgress: uploadProgress,
    ),
    MessageType.card => CardMessageContent(
      message: message,
      isFromMe: isFromMe,
    ),
    MessageType.merge => MergeMessageContent(
      message: message,
      isFromMe: isFromMe,
    ),
    MessageType.quote => QuoteMessageContent(
      message: message,
      isFromMe: isFromMe,
    ),
    MessageType.at => AtMessageContent(message: message, isFromMe: isFromMe),
    MessageType.face => FaceMessageContent(message: message),
    MessageType.location => LocationMessageContent(
      message: message,
      isFromMe: isFromMe,
    ),
    MessageType.custom => CustomMessageContent(
      message: message,
      isFromMe: isFromMe,
    ),
    MessageType.system => SystemMessageContent(message: message),
    MessageType.markdown => MarkdownMessageContent(
      message: message,
      isFromMe: isFromMe,
    ),
    _ => TextMessageContent(message: message, isFromMe: isFromMe),
  };
}
