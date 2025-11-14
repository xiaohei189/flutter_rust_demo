/// 消息类型
enum MessageType { text, image, voice, video, file }

/// 消息模型
class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isSent; // 是否已发送

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isSent = true,
  });

  // 判断是否是自己发送的消息
  bool get isFromMe => senderId == '1';
}
