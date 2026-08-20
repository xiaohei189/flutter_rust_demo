/// 消息领域模型（UI/Store 只依赖此模型，不直接依赖 Rust 生成模型）
class ChatMessage {
  final String clientMsgId;
  final String serverMsgId;
  final String sendId;
  final String recvId;
  final String groupId;
  final int senderPlatformId;
  final String senderNickname;
  final String senderFaceUrl;
  final int sessionType;
  final int msgFrom;
  final int contentType;
  final String content;
  final int seq;
  final int sendTime;
  final int createTime;
  final int status;
  final bool isRead;
  final String attachedInfo;
  final String ex;

  const ChatMessage({
    required this.clientMsgId,
    required this.serverMsgId,
    required this.sendId,
    required this.recvId,
    required this.groupId,
    required this.senderPlatformId,
    required this.senderNickname,
    required this.senderFaceUrl,
    required this.sessionType,
    required this.msgFrom,
    required this.contentType,
    required this.content,
    required this.seq,
    required this.sendTime,
    required this.createTime,
    required this.status,
    required this.isRead,
    required this.attachedInfo,
    required this.ex,
  });

  ChatMessage copyWith({
    String? clientMsgId,
    String? serverMsgId,
    String? sendId,
    String? recvId,
    String? groupId,
    int? senderPlatformId,
    String? senderNickname,
    String? senderFaceUrl,
    int? sessionType,
    int? msgFrom,
    int? contentType,
    String? content,
    int? seq,
    int? sendTime,
    int? createTime,
    int? status,
    bool? isRead,
    String? attachedInfo,
    String? ex,
  }) {
    return ChatMessage(
      clientMsgId: clientMsgId ?? this.clientMsgId,
      serverMsgId: serverMsgId ?? this.serverMsgId,
      sendId: sendId ?? this.sendId,
      recvId: recvId ?? this.recvId,
      groupId: groupId ?? this.groupId,
      senderPlatformId: senderPlatformId ?? this.senderPlatformId,
      senderNickname: senderNickname ?? this.senderNickname,
      senderFaceUrl: senderFaceUrl ?? this.senderFaceUrl,
      sessionType: sessionType ?? this.sessionType,
      msgFrom: msgFrom ?? this.msgFrom,
      contentType: contentType ?? this.contentType,
      content: content ?? this.content,
      seq: seq ?? this.seq,
      sendTime: sendTime ?? this.sendTime,
      createTime: createTime ?? this.createTime,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      attachedInfo: attachedInfo ?? this.attachedInfo,
      ex: ex ?? this.ex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          clientMsgId == other.clientMsgId &&
          serverMsgId == other.serverMsgId &&
          sendId == other.sendId &&
          recvId == other.recvId &&
          groupId == other.groupId &&
          senderPlatformId == other.senderPlatformId &&
          senderNickname == other.senderNickname &&
          senderFaceUrl == other.senderFaceUrl &&
          sessionType == other.sessionType &&
          msgFrom == other.msgFrom &&
          contentType == other.contentType &&
          content == other.content &&
          seq == other.seq &&
          sendTime == other.sendTime &&
          createTime == other.createTime &&
          status == other.status &&
          isRead == other.isRead &&
          attachedInfo == other.attachedInfo &&
          ex == other.ex;

  @override
  int get hashCode =>
      clientMsgId.hashCode ^
      serverMsgId.hashCode ^
      sendId.hashCode ^
      recvId.hashCode ^
      groupId.hashCode ^
      senderPlatformId.hashCode ^
      senderNickname.hashCode ^
      senderFaceUrl.hashCode ^
      sessionType.hashCode ^
      msgFrom.hashCode ^
      contentType.hashCode ^
      content.hashCode ^
      seq.hashCode ^
      sendTime.hashCode ^
      createTime.hashCode ^
      status.hashCode ^
      isRead.hashCode ^
      attachedInfo.hashCode ^
      ex.hashCode;
}

/// 历史消息分页结果（Repository 边界返回给 Domain 层的类型）
class MessageHistoryPage {
  final List<ChatMessage> messages;
  final bool isEnd;

  const MessageHistoryPage({required this.messages, required this.isEnd});
}
