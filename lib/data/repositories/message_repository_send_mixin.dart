import '../../domain/models/chat_message.dart' show ChatMessage;
import '../../generated/rust/ffi/client.dart' show OpenImBridgeClient;
import '../../generated/rust/constant/enums.dart' show SessionType;
import '../../generated/rust/ffi/message.dart' as ffi_message;
import '../../generated/rust/ffi/message_advanced.dart' as ffi_message_advanced;
import '../../generated/rust/ffi/message_builder.dart' as ffi_message_builder;
import '../../generated/rust/ffi/message_media.dart' as ffi_message_media;
import '../../generated/rust/http/message.dart' show RevokeMessageReq;
import '../../generated/rust/model/msg_struct.dart' show MsgStruct;
import '../mappers/message_mapper.dart' show messageFromMsgStruct;

/// 消息发送类 Repository 实现：文本/Markdown/@、媒体、转发、撤回、删除与重发。
mixin MessageRepositorySendMixin on Object {
  OpenImBridgeClient get client;

  Future<ChatMessage> sendTextMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await client.sendTextMessage(
        text: text,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendMarkdownMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await client.sendMarkdownMessage(
        text: text,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await client.sendAtTextMessage(
        text: text,
        atUserIds: atUserIds,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message_advanced.forwardMessageByClientId(
      clientMsgId: clientMsgId,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  Future<ChatMessage> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    final msg = await ffi_message_builder.createImageMessageFromFullPath(
      imageFullPath: filePath,
    );
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: msg,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendImageMessageFromUrl({
    required String sourceUrl,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await ffi_message_media.sendImageMessageFromUrl(
        sourceUrl: sourceUrl,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    final msg = await ffi_message_builder.createVideoMessageFromFullPath(
      videoFullPath: videoPath,
      videoType: extensionOf(videoPath),
      duration: duration,
      snapshotFullPath: snapshotPath,
    );
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: msg,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    final msg = await ffi_message_builder.createSoundMessageFromFullPath(
      soundPath: filePath,
      duration: duration,
    );
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: msg,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    final msg = await ffi_message_builder.createFileMessageFromFullPath(
      fileFullPath: filePath,
      fileName: fileNameOf(filePath),
    );
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: msg,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await ffi_message.sendLocationMessage(
        description: description,
        latitude: latitude,
        longitude: longitude,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await ffi_message.sendFaceMessage(
        index: index,
        data: data,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await ffi_message.sendCardMessage(
        userId: userId,
        nickname: nickname,
        faceUrl: faceUrl,
        ex: ex,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<ChatMessage> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  }) async {
    return messageFromMsgStruct(
      await ffi_message.sendQuoteMessage(
        text: text,
        sourceId: sourceId,
        sessionType: sessionType,
        quoteText: quoteText,
        quoteClientMsgId: quoteClientMsgId,
        quoteSendId: quoteSendId,
        quoteSendTime: quoteSendTime,
      ),
    );
  }

  Future<void> sendTyping({
    required String sourceId,
    required SessionType sessionType,
    required bool focus,
  }) {
    return ffi_message_advanced.sendTyping(
      sourceId: sourceId,
      sessionType: sessionType,
      focus: focus,
    );
  }

  Future<void> sendMergerMessage({
    required List<String> clientMsgIds,
    required String sourceConversationId,
    required String title,
    required List<String> summaryList,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message.sendMergerMessage(
      clientMsgIds: clientMsgIds,
      sourceConversationId: sourceConversationId,
      title: title,
      summaryList: summaryList,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  Future<ChatMessage> resendMessage({
    required ChatMessage message,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    final msgStruct = MsgStruct(
      clientMsgId: message.clientMsgId,
      serverMsgId: message.serverMsgId,
      createTime: message.createTime,
      sendTime: message.sendTime,
      sessionType: message.sessionType,
      sendId: message.sendId,
      recvId: message.recvId,
      msgFrom: message.msgFrom,
      contentType: message.contentType,
      senderPlatformId: message.senderPlatformId,
      senderNickname: message.senderNickname,
      senderFaceUrl: message.senderFaceUrl,
      groupId: message.groupId,
      content: message.content,
      seq: message.seq,
      isRead: message.isRead,
      status: message.status,
      attachedInfo: message.attachedInfo,
      ex: message.ex,
      localEx: '',
    );
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: msgStruct,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<void> revokeMessage({
    required String conversationId,
    required String userId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  }) {
    return client.revokeMessage(
      req: RevokeMessageReq(
        conversationId: conversationId,
        userId: userId,
        seq: seq,
        clientMsgId: clientMsgId,
        sessionType: sessionType,
      ),
    );
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  }) {
    return ffi_message_advanced.deleteMessage(
      conversationId: conversationId,
      clientMsgId: clientMsgId,
    );
  }
}

/// 从路径提取文件名（跨平台，支持 / 与 \ 分隔符）
String fileNameOf(String path) {
  final separator = path.contains('\\') ? '\\' : '/';
  return path.split(separator).last;
}

/// 从路径提取扩展名（不含点，无扩展名返回空串）
String extensionOf(String path) {
  final name = fileNameOf(path);
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1);
}
