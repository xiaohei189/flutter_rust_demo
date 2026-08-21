import '../../domain/models/conversation.dart';
import '../../domain/models/chat_message.dart'
    show ChatMessage, MessageHistoryPage;
import '../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../domain/models/user_profile.dart' show UserProfile;
import '../../generated/rust/constant/enums.dart' show SessionType;

export 'message_repository_impl.dart';

abstract class MessageRepository {
  Future<List<UserProfile>> getUsersInfo(List<String> userIds);

  Future<void> updateUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
  });

  Future<void> setGlobalMsgRecvOpt({required int globalRecvOpt});

  Future<MessageHistoryPage> getHistoryMessages({
    required String conversationId,
    required String startClientMsgId,
    required int count,
  });

  Future<ChatMessage> sendTextMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendMarkdownMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<List<MessageSearchResult>> searchLocalMessages({
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

  Future<ChatMessage> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendImageMessageFromUrl({
    required String sourceUrl,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  });

  Future<ChatMessage> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  });

  Future<ChatMessage> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  });

  Future<void> sendTyping({
    required String sourceId,
    required SessionType sessionType,
    required bool focus,
  });

  Future<void> sendMergerMessage({
    required List<String> clientMsgIds,
    required String sourceConversationId,
    required String title,
    required List<String> summaryList,
    required String sourceId,
    required SessionType sessionType,
  });

  Future<ChatMessage> resendMessage({
    required ChatMessage message,
    required String sourceId,
    required SessionType sessionType,
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
    required ChatSessionType sessionType,
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
    int? recvMsgOpt,
    String? ex,
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

  Future<void> hideAllConversations();

  Future<void> clearConversationAndDeleteAllMsg(String conversationId);

  Future<void> markAllConversationsAsRead();
}
