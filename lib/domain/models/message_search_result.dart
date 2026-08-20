/// 本地消息搜索结果（Repository 边界返回给 Domain 层的类型）
class MessageSearchResult {
  final String conversationId;
  final String clientMsgId;
  final String serverMsgId;
  final String sendId;
  final String recvId;
  final int senderPlatformId;
  final String senderNickName;
  final String senderFaceUrl;
  final int sessionType;
  final int msgFrom;
  final int contentType;
  final String content;
  final bool isRead;
  final int status;
  final int seq;
  final int sendTime;
  final int createTime;
  final String attachedInfo;
  final String ex;
  final String localEx;
  final String groupId;

  const MessageSearchResult({
    required this.conversationId,
    required this.clientMsgId,
    required this.serverMsgId,
    required this.sendId,
    required this.recvId,
    required this.senderPlatformId,
    required this.senderNickName,
    required this.senderFaceUrl,
    required this.sessionType,
    required this.msgFrom,
    required this.contentType,
    required this.content,
    required this.isRead,
    required this.status,
    required this.seq,
    required this.sendTime,
    required this.createTime,
    required this.attachedInfo,
    required this.ex,
    required this.localEx,
    required this.groupId,
  });
}