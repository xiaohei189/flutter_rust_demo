import 'dart:typed_data' show Int32List;

import '../services/im_client.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/chat_message.dart'
    show ChatMessage, MessageHistoryPage;
import '../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../domain/models/user_profile.dart'
    show UserProfile, UserProfileMapping;
import '../mappers/message_mapper.dart';
import '../../generated/rust/client.dart';
import '../../generated/rust/constant/enums.dart' show SessionType;
import '../../generated/rust/ffi/client.dart';
import '../../generated/rust/ffi/message.dart' as ffi_message;
import '../../generated/rust/ffi/message_advanced.dart' as ffi_message_advanced;
import '../../generated/rust/ffi/message_builder.dart' as ffi_message_builder;
import '../../generated/rust/ffi/message_media.dart' as ffi_message_media;
import '../../generated/rust/http/message.dart' show RevokeMessageReq;
import '../../generated/rust/model/msg_struct.dart' show MsgStruct;

import 'message_repository.dart';

class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl({required ImClient imClient}) : _imClient = imClient;

  final ImClient _imClient;

  OpenImBridgeClient get _client {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  @override
  Future<List<UserProfile>> getUsersInfo(List<String> userIds) async {
    final raw = await _client.getUsersInfo(userIds: userIds);
    return raw.map(UserProfileMapping.fromUserInfo).toList(growable: false);
  }

  @override
  Future<void> updateUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
  }) {
    return _client.updateUserProfile(
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
    );
  }

  @override
  Future<void> setGlobalMsgRecvOpt({required int globalRecvOpt}) {
    return _client.setGlobalMsgRecvOpt(globalRecvOpt: globalRecvOpt);
  }

  @override
  Future<MessageHistoryPage> getHistoryMessages({
    required String conversationId,
    required String startClientMsgId,
    required int count,
  }) async {
    final raw = await _client.getHistoryMessages(
      req: GetHistoryMessagesReq(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId,
        count: count,
      ),
    );
    return MessageHistoryPage(
      messages: messagesFromMessageInfos(raw.messages),
      isEnd: raw.isEnd,
    );
  }

  @override
  Future<ChatMessage> sendTextMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await _client.sendTextMessage(
        text: text,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  @override
  Future<ChatMessage> sendMarkdownMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await _client.sendMarkdownMessage(
        text: text,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  @override
  Future<ChatMessage> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await _client.sendAtTextMessage(
        text: text,
        atUserIds: atUserIds,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  @override
  Future<List<MessageSearchResult>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) async {
    final raw = await _client.searchLocalMessages(
      req: SearchMessagesReq(
        conversationId: conversationId,
        keyword: keyword.trim(),
        senderUserIds: const [],
        messageTypes: Int32List(0),
        startTime: 0,
        endTime: 0,
        offset: offset,
        count: count,
      ),
    );
    return raw.map(messageSearchResultFromLocalChatLog).toList(growable: false);
  }

  @override
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

  @override
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

  @override
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

  @override
  Future<ChatMessage> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    final msg = await ffi_message_builder.createVideoMessageFromFullPath(
      videoFullPath: videoPath,
      videoType: _extensionOf(videoPath),
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

  @override
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

  @override
  Future<ChatMessage> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    final msg = await ffi_message_builder.createFileMessageFromFullPath(
      fileFullPath: filePath,
      fileName: _fileNameOf(filePath),
    );
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: msg,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<void> revokeMessage({
    required String conversationId,
    required String userId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  }) {
    return _client.revokeMessage(
      req: RevokeMessageReq(
        conversationId: conversationId,
        userId: userId,
        seq: seq,
        clientMsgId: clientMsgId,
        sessionType: sessionType,
      ),
    );
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  }) {
    return ffi_message_advanced.deleteMessage(
      conversationId: conversationId,
      clientMsgId: clientMsgId,
    );
  }

  @override
  Future<List<Conversation>> getConversations() async {
    final conversations = await _client.getConversations();
    return conversations
        .map(ConversationMapping.fromLocalConversation)
        .toList();
  }

  @override
  Future<String> getConversationIdBySessionType({
    required String sourceId,
    required ChatSessionType sessionType,
  }) {
    return _client.getConversationIdBySessionType(
      sourceId: sourceId,
      sessionType: SessionType.values[sessionType.index],
    );
  }

  @override
  Future<bool> isInBlacklist(String userId) {
    return _client.isInBlacklist(userId: userId);
  }

  @override
  Future<void> markConversationMessageAsRead({
    required String conversationId,
    required SessionType sessionType,
  }) {
    return _client.markConversationMessageAsRead(
      conversationId: conversationId,
      sessionType: sessionType,
    );
  }

  @override
  Future<void> setConversationDraft({
    required String conversationId,
    required String draftText,
  }) {
    return _client.setConversationDraft(
      conversationId: conversationId,
      draftText: draftText,
    );
  }

  @override
  Future<void> clearConversationDraft({required String conversationId}) {
    return _client.clearConversationDraft(conversationId: conversationId);
  }

  @override
  Future<void> setConversation({
    required String conversationId,
    int? recvMsgOpt,
    String? ex,
  }) {
    return _client.setConversation(
      conversationId: conversationId,
      recvMsgOpt: recvMsgOpt,
      ex: ex,
    );
  }

  @override
  Future<void> setConversationPrivate({
    required String conversationId,
    required bool isPrivate,
  }) {
    return _client.setConversationPrivate(
      conversationId: conversationId,
      isPrivate: isPrivate,
    );
  }

  @override
  Future<void> setConversationPinned({
    required String conversationId,
    required bool isPinned,
  }) {
    return _client.setConversationPinned(
      conversationId: conversationId,
      isPinned: isPinned,
    );
  }

  @override
  Future<void> deleteConversation({required String conversationId}) {
    return _client.deleteConversation(conversationId: conversationId);
  }

  @override
  Future<void> hideConversation({required String conversationId}) {
    return _client.hideConversation(conversationId: conversationId);
  }

  @override
  Future<void> hideAllConversations() {
    return _client.hideAllConversations();
  }

  @override
  Future<void> clearConversationAndDeleteAllMsg(String conversationId) {
    return ffi_message_advanced.clearConversationAndDeleteAllMsg(
      conversationId: conversationId,
    );
  }

  @override
  Future<void> markAllConversationsAsRead() {
    return ffi_message_advanced.markAllConversationMessageAsRead();
  }
}

/// 从路径提取文件名（跨平台，支持 / 与 \ 分隔符）
String _fileNameOf(String path) {
  final separator = path.contains('\\') ? '\\' : '/';
  return path.split(separator).last;
}

/// 从路径提取扩展名（不含点，无扩展名返回空串）
String _extensionOf(String path) {
  final name = _fileNameOf(path);
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1);
}
