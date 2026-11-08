import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/chat_message.dart';
import '../../domain/models/topic.dart';
import 'message_mapper.dart' show normalizeMessageSendTime;

ChatMessage chatMessageFromTopicJson(Map<String, dynamic> json) {
  final sendTime = normalizeMessageSendTime(_int(json['sendTime']));
  return ChatMessage(
    clientMsgId: json['clientMsgID']?.toString() ?? '',
    serverMsgId: json['serverMsgID']?.toString() ?? '',
    sendId: json['sendID']?.toString() ?? '',
    recvId: json['recvID']?.toString() ?? '',
    groupId: json['groupID']?.toString() ?? '',
    senderPlatformId: _int(json['senderPlatformID']),
    senderNickname: json['senderNickname']?.toString() ?? '',
    senderFaceUrl: json['senderFaceURL']?.toString() ?? '',
    sessionType: _int(json['sessionType']),
    msgFrom: _int(json['msgFrom']),
    contentType: _int(json['contentType']),
    content: _decodeContent(json['content']),
    seq: _int(json['seq']),
    sendTime: sendTime,
    createTime: json['createTime'] == null
        ? sendTime
        : normalizeMessageSendTime(_int(json['createTime'])),
    status: _int(json['status']),
    isRead: json['isRead'] == true,
    attachedInfo: json['attachedInfo']?.toString() ?? '',
    ex: json['ex']?.toString() ?? '',
    topicId: json['topicID']?.toString() ?? '',
  );
}

TopicFeedPage topicFeedPageFromJson(Map<String, dynamic> json) {
  return TopicFeedPage(
    items: _maps(json['items'])
        .map(TopicFeedItem.fromJson)
        .toList(growable: false),
    nextCursor: json['nextCursor']?.toString() ?? '',
    hasMore: json['hasMore'] == true,
  );
}

TopicDetail topicDetailFromJson(Map<String, dynamic> json) {
  final topicJson = _map(json['topic']);
  final messageJson = _map(json['rootMessage']);
  return TopicDetail(
    topic: Topic.fromJson(topicJson),
    rootMessage: messageJson.isEmpty ? null : chatMessageFromTopicJson(messageJson),
  );
}

TopicReplyPage topicReplyPageFromJson(Map<String, dynamic> json) {
  final replies = <TopicReply>[];
  for (final item in _maps(json['replies'])) {
    final messageJson = _map(item['message']);
    if (messageJson.isEmpty) continue;
    replies.add(
      TopicReply(
        message: chatMessageFromTopicJson(messageJson),
        revoked: item['revoked'] == true,
      ),
    );
  }
  return TopicReplyPage(
    replies: replies,
    nextBeforeSeq: _int(json['nextBeforeSeq']),
    hasMore: json['hasMore'] == true,
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<Object?, Object?>) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _decodeContent(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty || text.startsWith('{') || text.startsWith('[')) {
    return text;
  }
  try {
    return utf8.decode(base64Decode(text));
  } catch (_) {
    return text;
  }
}

String uint8ListToText(Uint8List bytes) => utf8.decode(bytes);
