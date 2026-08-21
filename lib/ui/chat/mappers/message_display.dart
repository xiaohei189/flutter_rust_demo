import 'message_media.dart';
import 'message_parsed.dart' show parsedContentOf;
import 'message_system_text.dart' show readableSystemMessage;

export 'message_converters.dart';
export 'message_media.dart';
export 'message_search_display.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/message.dart'
    show MessageType, MessageSendStatus, messageTypeFromContentType;

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
