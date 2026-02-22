/// 消息类型
enum MessageType { text, image, voice, video, file }

/// 发送状态（自己发出的消息）
enum MessageSendStatus {
  sending,
  sent,
  failed,
}

/// 消息模型
class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isSent; // 是否为自己发送
  /// 发送状态，仅自己发送的消息有效；null 表示历史消息默认已送达
  final MessageSendStatus? sendStatus;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isSent = true,
    this.sendStatus,
  });

  /// 复制并更新发送状态
  Message copyWith({MessageSendStatus? sendStatus}) {
    return Message(
      id: id,
      senderId: senderId,
      content: content,
      type: type,
      timestamp: timestamp,
      isSent: isSent,
      sendStatus: sendStatus ?? this.sendStatus,
    );
  }

  // 判断是否是自己发送的消息
  bool get isFromMe => senderId == '1';
}
