import 'dart:convert';

import '../../../../domain/models/chat_message.dart' show ChatMessage;

ChatMessage messageSentToChatMessage({
  required String clientMsgId,
  required String serverMsgId,
  required int sendTimeMs,
  required int status,
  required String conversationId,
  required String sendId,
  required String recvId,
  required String groupId,
  required int sessionType,
  required int contentType,
  required String content,
  required String senderNickname,
  required String senderFaceUrl,
}) => ChatMessage(
  clientMsgId: clientMsgId,
  serverMsgId: serverMsgId,
  sendId: sendId,
  recvId: recvId,
  groupId: groupId,
  senderPlatformId: 0,
  senderNickname: senderNickname,
  senderFaceUrl: senderFaceUrl,
  sessionType: sessionType,
  msgFrom: 0,
  contentType: contentType,
  content: content,
  seq: 0,
  sendTime: sendTimeMs,
  createTime: sendTimeMs,
  status: status,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

/// 将合并转发 `multiMessage` 中的子消息 JSON 还原为 [MessageInfo]。
///
/// 兼容两种序列化来源：
/// - 本 SDK（Rust `MsgStruct` camelCase）：`clientMsgId` / `sendId` / `groupId` ...
/// - Go SDK（`openim-sdk-core` `MsgStruct`）：`clientMsgID` / `sendID` / `groupID` ...
ChatMessage mergeSubMessageFromJson(Map<String, dynamic> json) {
  String pickString(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  int pickInt(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  bool pickBool(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is bool) return v;
    }
    return false;
  }

  // Go SDK 在 msgHandleByContentType 解析后会把 content 清空、只保留 typed elem
  // （pictureElem/textElem 等）。这里若 content 为空，则把 typed elem 编码回
  // content JSON，保证 UI 层按 content 解析仍能拿到图片/文本等数据。
  var content = pickString(['content']);
  if (content.isEmpty) {
    content = _mergeSubElemToContent(json);
  }

  final sessionType = pickInt(['sessionType']);
  return ChatMessage(
    clientMsgId: pickString(['clientMsgID', 'clientMsgId']),
    serverMsgId: pickString(['serverMsgID', 'serverMsgId']),
    sendId: pickString(['sendID', 'sendId']),
    recvId: pickString(['recvID', 'recvId']),
    groupId: pickString(['groupID', 'groupId']),
    senderPlatformId: pickInt(['senderPlatformID', 'senderPlatformId']),
    senderNickname: pickString(['senderNickname']),
    senderFaceUrl: pickString(['senderFaceUrl', 'senderFaceURL']),
    sessionType: sessionType != 0 ? sessionType : 1,
    msgFrom: pickInt(['msgFrom']),
    contentType: pickInt(['contentType']),
    content: content,
    seq: pickInt(['seq']),
    sendTime: pickInt(['sendTime']),
    createTime: pickInt(['createTime']),
    status: pickInt(['status']),
    isRead: pickBool(['isRead']),
    attachedInfo: pickString(['attachedInfo']),
    ex: pickString(['ex']),
  );
}

/// Go SDK 会把合并消息子消息的 content 置空、仅保留 typed elem，
/// 这里把第一个非空 typed elem 编码回 content JSON（对齐官方 Web 的
/// `message.pictureElem.sourcePicture.url` 读取方式）。
String _mergeSubElemToContent(Map<String, dynamic> json) {
  const elemKeys = [
    'textElem',
    'pictureElem',
    'soundElem',
    'videoElem',
    'fileElem',
    'atTextElem',
    'quoteElem',
    'mergeElem',
    'cardElem',
    'locationElem',
    'faceElem',
    'customElem',
    'advancedTextElem',
    'markdownTextElem',
  ];
  for (final key in elemKeys) {
    final elem = json[key];
    if (elem is Map<String, dynamic> && elem.isNotEmpty) {
      return jsonEncode(elem);
    }
  }
  return '';
}

