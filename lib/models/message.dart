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
  final bool isSent;
  final MessageSendStatus? sendStatus;
  final String? senderNickname;
  final String? senderFaceUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isSent = true,
    this.sendStatus,
    this.senderNickname,
    this.senderFaceUrl,
  });

  Message copyWith({MessageSendStatus? sendStatus}) {
    return Message(
      id: id,
      senderId: senderId,
      content: content,
      type: type,
      timestamp: timestamp,
      isSent: isSent,
      sendStatus: sendStatus ?? this.sendStatus,
      senderNickname: senderNickname,
      senderFaceUrl: senderFaceUrl,
    );
  }

  bool get isFromMe => isSent;
}
