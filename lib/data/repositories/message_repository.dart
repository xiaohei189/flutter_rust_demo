import 'dart:typed_data' show Int32List;

import '../services/im_client.dart';
import '../../domain/models/conversation.dart';
import '../../generated/rust/client.dart';
import '../../generated/rust/constant/enums.dart' show SessionType;
import '../../generated/rust/ffi/client.dart';
import '../../generated/rust/ffi/message.dart' as ffi_message;
import '../../generated/rust/ffi/message_advanced.dart' as ffi_message_advanced;
import '../../generated/rust/http/message.dart' show RevokeMessageReq;
import '../../generated/rust/model/local.dart' show LocalChatLog;
import '../../generated/rust/model/msg_struct.dart' show MsgStruct;
import '../../generated/rust/model/user.dart' show UserInfo;

abstract class MessageRepository {
  Future<List<UserInfo>> getUsersInfo(List<String> userIds);

  Future<void> updateUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
  });

  Future<void> setGlobalMsgRecvOpt({required int globalRecvOpt});

  Future<GetHistoryMessagesResult> getHistoryMessages({
    required String conversationId,
    required String startClientMsgId,
    required int count,
  });

  Future<MsgStruct> sendTextMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendMarkdownMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<List<LocalChatLog>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  });

  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  });

  Future<MsgStruct> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  });

  Future<MsgStruct> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<MsgStruct> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  });

  Future<void> revokeMessage({
    required String conversationId,
    required String userId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  });

  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  });

  Future<List<Conversation>> getConversations();

  Future<String> getConversationIdBySessionType({
    required String sourceId,
    required SessionType sessionType,
  });

  Future<bool> isInBlacklist(String userId);

  Future<void> markConversationMessageAsRead({
    required String conversationId,
    required SessionType sessionType,
  });

  Future<void> setConversationDraft({
    required String conversationId,
    required String draftText,
  });

  Future<void> clearConversationDraft({required String conversationId});

  Future<void> setConversation({
    required String conversationId,
    required int recvMsgOpt,
  });

  Future<void> setConversationPrivate({
    required String conversationId,
    required bool isPrivate,
  });

  Future<void> setConversationPinned({
    required String conversationId,
    required bool isPinned,
  });

  Future<void> deleteConversation({required String conversationId});

  Future<void> hideConversation({required String conversationId});

  Future<void> clearConversationAndDeleteAllMsg(String conversationId);

  Future<void> markAllConversationsAsRead();
}

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
  Future<List<UserInfo>> getUsersInfo(List<String> userIds) {
    return _client.getUsersInfo(userIds: userIds);
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
  Future<GetHistoryMessagesResult> getHistoryMessages({
    required String conversationId,
    required String startClientMsgId,
    required int count,
  }) {
    return _client.getHistoryMessages(
      req: GetHistoryMessagesReq(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId,
        count: count,
      ),
    );
  }

  @override
  Future<MsgStruct> sendTextMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return _client.sendTextMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendMarkdownMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return _client.sendMarkdownMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return _client.sendAtTextMessage(
      text: text,
      atUserIds: atUserIds,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<List<LocalChatLog>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) {
    return _client.searchLocalMessages(
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
  Future<MsgStruct> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return _client.sendImageMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) {
    return _client.sendVideoMessage(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  @override
  Future<MsgStruct> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) {
    return _client.sendSoundMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  @override
  Future<MsgStruct> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return _client.sendFileMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message.sendLocationMessage(
      description: description,
      latitude: latitude,
      longitude: longitude,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message.sendFaceMessage(
      index: index,
      data: data,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message.sendCardMessage(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  @override
  Future<MsgStruct> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  }) {
    return ffi_message.sendQuoteMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
      quoteText: quoteText,
      quoteClientMsgId: quoteClientMsgId,
      quoteSendId: quoteSendId,
      quoteSendTime: quoteSendTime,
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
    required SessionType sessionType,
  }) {
    return _client.getConversationIdBySessionType(
      sourceId: sourceId,
      sessionType: sessionType,
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
    required int recvMsgOpt,
  }) {
    return _client.setConversation(
      conversationId: conversationId,
      recvMsgOpt: recvMsgOpt,
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
