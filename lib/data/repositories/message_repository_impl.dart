import 'dart:typed_data' show Int32List;

import '../services/im_client.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/chat_message.dart' show MessageHistoryPage;
import '../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../domain/models/user_profile.dart'
    show UserProfile, UserProfileMapping;
import '../mappers/message_mapper.dart';
import '../../generated/rust/client.dart';
import '../../generated/rust/constant/enums.dart' show SessionType;
import '../../generated/rust/ffi/message_advanced.dart' as ffi_message_advanced;
import '../../generated/rust/ffi/client.dart';

import 'message_repository.dart';
import 'message_repository_send_mixin.dart';

class MessageRepositoryImpl
    with MessageRepositorySendMixin
    implements MessageRepository {
  MessageRepositoryImpl({required ImClient imClient}) : _imClient = imClient;

  final ImClient _imClient;

  @override
  OpenImBridgeClient get client {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  @override
  Future<List<UserProfile>> getUsersInfo(List<String> userIds) async {
    final raw = await client.getUsersInfo(userIds: userIds);
    return raw.map(UserProfileMapping.fromUserInfo).toList(growable: false);
  }

  @override
  Future<void> updateUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
  }) {
    return client.updateUserProfile(
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
    );
  }

  @override
  Future<void> setGlobalMsgRecvOpt({required int globalRecvOpt}) {
    return client.setGlobalMsgRecvOpt(globalRecvOpt: globalRecvOpt);
  }

  @override
  Future<MessageHistoryPage> getHistoryMessages({
    required String conversationId,
    required String startClientMsgId,
    required int count,
  }) async {
    final raw = await client.getHistoryMessages(
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
  Future<List<MessageSearchResult>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) async {
    final raw = await client.searchLocalMessages(
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
  Future<List<Conversation>> getConversations() async {
    final conversations = await client.getConversations();
    return conversations
        .map(ConversationMapping.fromLocalConversation)
        .toList();
  }

  @override
  Future<String> getConversationIdBySessionType({
    required String sourceId,
    required ChatSessionType sessionType,
  }) {
    return client.getConversationIdBySessionType(
      sourceId: sourceId,
      sessionType: SessionType.values[sessionType.index],
    );
  }

  @override
  Future<bool> isInBlacklist(String userId) {
    return client.isInBlacklist(userId: userId);
  }

  @override
  Future<void> markConversationMessageAsRead({
    required String conversationId,
    required SessionType sessionType,
  }) {
    return client.markConversationMessageAsRead(
      conversationId: conversationId,
      sessionType: sessionType,
    );
  }

  @override
  Future<void> setConversationDraft({
    required String conversationId,
    required String draftText,
  }) {
    return client.setConversationDraft(
      conversationId: conversationId,
      draftText: draftText,
    );
  }

  @override
  Future<void> clearConversationDraft({required String conversationId}) {
    return client.clearConversationDraft(conversationId: conversationId);
  }

  @override
  Future<void> setConversation({
    required String conversationId,
    int? recvMsgOpt,
    String? ex,
  }) {
    return client.setConversation(
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
    return client.setConversationPrivate(
      conversationId: conversationId,
      isPrivate: isPrivate,
    );
  }

  @override
  Future<void> setConversationPinned({
    required String conversationId,
    required bool isPinned,
  }) {
    return client.setConversationPinned(
      conversationId: conversationId,
      isPinned: isPinned,
    );
  }

  @override
  Future<void> deleteConversation({required String conversationId}) {
    return client.deleteConversation(conversationId: conversationId);
  }

  @override
  Future<void> hideConversation({required String conversationId}) {
    return client.hideConversation(conversationId: conversationId);
  }

  @override
  Future<void> hideAllConversations() {
    return client.hideAllConversations();
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
