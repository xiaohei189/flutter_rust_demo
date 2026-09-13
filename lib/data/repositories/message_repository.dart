import '../../domain/models/conversation.dart';
import '../../domain/models/chat_message.dart'
    show ChatMessage, MessageHistoryPage;
import '../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../domain/models/user_profile.dart' show UserProfile;
import '../../generated/rust/constant/enums.dart' show SessionType;
import '../../generated/rust/model/msg_struct.dart' show MsgStruct;

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

  Future<ChatMessage> sendPreparedMessage({
    required MsgStruct message,
    required String sourceId,
    required SessionType sessionType,
  });

  // ---- 本地消息构造（对齐 Go SDK CreateXxxMessage）----

  /// 构造本地文本消息：不发网络，供上层乐观上屏
  Future<MsgStruct> createTextMessage({required String text});

  /// 构造本地 Markdown 消息
  Future<MsgStruct> createMarkdownMessage({required String text});

  /// 构造本地 @ 消息
  Future<MsgStruct> createAtTextMessage({
    required String text,
    required List<String> atUserIds,
  });

  /// 构造本地图片消息（本地文件，发送时上传 OSS）
  Future<MsgStruct> createImageMessage({required String filePath});

  /// 构造内容已上传的 URL 图片消息（GIF/表情，不走 OSS）
  Future<MsgStruct> createImageMessageFromUrl({required String sourceUrl});

  /// 构造本地视频消息
  Future<MsgStruct> createVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required int duration,
  });

  /// 构造本地语音消息
  Future<MsgStruct> createSoundMessage({
    required String filePath,
    required int duration,
  });

  /// 构造本地文件消息
  Future<MsgStruct> createFileMessage({required String filePath});

  /// 构造本地位置消息
  Future<MsgStruct> createLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
  });

  /// 构造本地表情消息
  Future<MsgStruct> createFaceMessage({
    required int index,
    required String data,
  });

  /// 构造本地名片消息
  Future<MsgStruct> createCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
  });

  /// 构造本地引用消息
  Future<MsgStruct> createQuoteMessage({
    required String text,
    required ChatMessage quoted,
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
