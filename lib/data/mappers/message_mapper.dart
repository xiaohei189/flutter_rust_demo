import '../../domain/models/chat_message.dart';
import '../../generated/rust/model/message.dart' show MessageInfo;
import '../../generated/rust/model/msg_struct.dart' show MsgStruct;

/// 将 sendTime 规范化为毫秒（自动检测秒/毫秒）
int normalizeMessageSendTime(int t) {
  if (t <= 0) return DateTime.now().millisecondsSinceEpoch;
  if (t < 946684800000) return t * 1000;
  return t;
}

ChatMessage messageFromMessageInfo(MessageInfo raw) {
  return ChatMessage(
    clientMsgId: raw.clientMsgId,
    serverMsgId: raw.serverMsgId,
    sendId: raw.sendId,
    recvId: raw.recvId,
    groupId: raw.groupId,
    senderPlatformId: raw.senderPlatformId,
    senderNickname: raw.senderNickname,
    senderFaceUrl: raw.senderFaceUrl,
    sessionType: raw.sessionType,
    msgFrom: raw.msgFrom,
    contentType: raw.contentType,
    content: raw.content,
    seq: raw.seq,
    sendTime: normalizeMessageSendTime(raw.sendTime.toInt()),
    createTime: raw.createTime > 0
        ? normalizeMessageSendTime(raw.createTime.toInt())
        : normalizeMessageSendTime(raw.sendTime.toInt()),
    status: raw.status,
    isRead: raw.isRead,
    attachedInfo: raw.attachedInfo,
    ex: raw.ex,
  );
}

List<ChatMessage> messagesFromMessageInfos(Iterable<MessageInfo> raw) {
  return raw.map(messageFromMessageInfo).toList(growable: false);
}

ChatMessage messageFromMsgStruct(MsgStruct raw) {
  final sendTime = normalizeMessageSendTime(raw.sendTime.toInt());
  return ChatMessage(
    clientMsgId: raw.clientMsgId,
    serverMsgId: raw.serverMsgId,
    sendId: raw.sendId,
    recvId: raw.recvId,
    groupId: raw.groupId,
    senderPlatformId: raw.senderPlatformId,
    senderNickname: raw.senderNickname,
    senderFaceUrl: raw.senderFaceUrl,
    sessionType: raw.sessionType,
    msgFrom: raw.msgFrom,
    contentType: raw.contentType,
    content: raw.content,
    seq: raw.seq,
    sendTime: sendTime,
    createTime: raw.createTime > 0
        ? normalizeMessageSendTime(raw.createTime.toInt())
        : sendTime,
    status: raw.status,
    isRead: false,
    attachedInfo: '',
    ex: '',
  );
}
MessageInfo messageInfoFromChatMessage(ChatMessage message) {
  return MessageInfo(
    clientMsgId: message.clientMsgId,
    serverMsgId: message.serverMsgId,
    sendId: message.sendId,
    recvId: message.recvId,
    groupId: message.groupId,
    senderPlatformId: message.senderPlatformId,
    senderNickname: message.senderNickname,
    senderFaceUrl: message.senderFaceUrl,
    sessionType: message.sessionType,
    msgFrom: message.msgFrom,
    contentType: message.contentType,
    content: message.content,
    seq: message.seq,
    sendTime: message.sendTime,
    createTime: message.createTime,
    status: message.status,
    isRead: message.isRead,
    attachedInfo: message.attachedInfo,
    ex: message.ex,
  );
}