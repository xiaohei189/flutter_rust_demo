import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;
import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/domain/models/user_profile.dart'
    show UserProfile;
import 'package:flutter_rust_demo/generated/rust/model/local.dart'
    show LocalConversation;
import 'package:flutter_rust_demo/generated/rust/event/events/connection.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/friend.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/group.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/message.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/user.dart';
import 'package:flutter_rust_demo/core/utils/app_logger.dart';
import 'package:flutter_rust_demo/providers/online_status_provider.dart';
import 'package:flutter_rust_demo/providers/im_providers.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'message_event_applier.dart';
import 'message_history_controller.dart';
import 'message_service_reducer.dart';
import 'message_service_connection_controller.dart';
import 'message_user_profile_controller.dart';
import 'message_service_conversation_controller.dart';

import 'message_send_controller.dart';
import 'message_send_pipeline.dart';
import 'message_service_social_controller.dart';

/// MessageService 的 Notifier
class MessageServiceNotifier extends Notifier<MessageServiceState> {
  final List<StreamSubscription<dynamic>> subscriptions = [];

  /// 已处理的 clientMsgId 集合，防止同一消息被重复添加到列表
  final Set<String> seenClientMsgIds = {};

  MessageServiceConnectionController? _connectionController;
  MessageServiceConversationController? _conversationController;
  MessageServiceSocialController? _socialController;
  MessageSendController? _sendController;
  MessageSendPipeline? _sendPipeline;

  @override
  MessageServiceState build() => MessageServiceState();

  MessageServiceConnectionController get connectionController =>
      _connectionController ??= MessageServiceConnectionController(
        this,
        ref.read(connectionServiceProvider),
        ref.read(onlineStatusServiceProvider),
        ref.read(imClientProvider),
        ref.read(navigationServiceProvider),
      );

  MessageServiceConversationController get conversationController =>
      _conversationController ??= MessageServiceConversationController(
        this,
        ref.read(imClientProvider),
      );

  MessageServiceSocialController get socialController =>
      _socialController ??= MessageServiceSocialController(
        this,
        ref.read(onlineStatusServiceProvider),
      );

  MessageSendController get sendController =>
      _sendController ??= MessageSendController(
        this,
        ref.read(messageRepositoryProvider),
        ref.read(imClientProvider),
      );

  /// 发送链路（唯一发送入口：create → 乐观上屏 → send → 状态收敛）
  MessageSendPipeline get sendPipeline => _sendPipeline ??= MessageSendPipeline(
    service: this,
    repository: ref.read(messageRepositoryProvider),
    isClientReady: () => ref.read(imClientProvider).isInitialized,
  );

  MessageRepository get repository => ref.read(messageRepositoryProvider);

  /// 对外只读状态快照（避免外部访问 StateNotifier 的 protected state）
  MessageServiceState get currentState => state;

  void updateState(MessageServiceState next) => state = next;

  void onConnectionEvent(ConnectionEvent event) =>
      connectionController.handleEvent(event);

  void onConversationEvent(ConversationEvent event) =>
      conversationController.handleEvent(event);

  void onFriendEvent(FriendEvent event) =>
      socialController.handleFriendEvent(event);

  void onGroupEvent(GroupEvent event) =>
      socialController.handleGroupEvent(event);

  void onMessageEvent(MessageEvent event) => _onMessageEvent(event);

  void onUserEvent(UserEvent event) => socialController.handleUserEvent(event);

  void applyConversationEvent(List<LocalConversation> incoming) =>
      eventApplier.applyConversationEvent(incoming);

  List<ChatMessage> getMessages(String conversationId) =>
      historyController.getMessages(conversationId);

  void upsertSentMessage(String conversationId, ChatMessage result) =>
      historyController.upsertSentMessage(conversationId, result);

  /// 发送状态收敛（1=发送中/2=成功/3=失败），幂等
  void applySendStatus(String conversationId, String clientMsgId, int status) =>
      updateState(
        MessageServiceReducer.applySendStatus(
          currentState,
          conversationId,
          clientMsgId,
          status,
        ),
      );

  /// 发送成功后就地合并服务端消息（保持同一 clientMsgId，不新增气泡）
  void mergeSentMessage(
    String conversationId,
    String clientMsgId,
    ChatMessage sent,
  ) => updateState(
    MessageServiceReducer.mergeSentMessage(
      currentState,
      conversationId,
      clientMsgId,
      sent,
    ),
  );

  /// 获取指定用户资料（命中缓存时）
  UserProfile? getUserProfile(String userId) => state.userProfiles[userId];

  MessageHistoryController? _historyController;

  MessageHistoryController get historyController => _historyController ??=
      MessageHistoryController(this, ref.read(imClientProvider), repository);

  MessageEventApplier? _eventApplier;

  MessageEventApplier get eventApplier => _eventApplier ??= MessageEventApplier(
    this,
    ref.read(appLifecycleServiceProvider),
    ref.read(localNotificationServiceProvider),
  );

  MessageUserProfileController? _userProfileController;

  MessageUserProfileController get userProfileController =>
      _userProfileController ??= MessageUserProfileController(
        this,
        ref.read(imClientProvider),
        repository,
      );

  Future<UserProfile?> refreshLoginUserProfile() =>
      userProfileController.refreshLoginUserProfile();

  Future<void> preloadUserProfiles(List<String> userIds) =>
      userProfileController.preloadUserProfiles(userIds);

  Future<UserProfile?> updateLoginUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
    int? globalRecvMsgOpt,
  }) => userProfileController.updateLoginUserProfile(
    nickname: nickname,
    faceUrl: faceUrl,
    ex: ex,
    globalRecvMsgOpt: globalRecvMsgOpt,
  );

  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    String startClientMsgId = '',
  }) => historyController.loadHistoryMessages(
    conversationId,
    count: count,
    startClientMsgId: startClientMsgId,
  );

  Future<PendingSend> sendTextMessage({
    required String recvId,
    required String text,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) => sendPipeline.sendText(
    conversationId: conversationId,
    sourceId: _sourceId(recvId, groupId),
    sessionType: sessionType,
    text: text,
  );

  /// 会话目标 ID：群聊取 groupId，单聊取 recvId（与 SDK sourceId 语义一致）
  String _sourceId(String recvId, String groupId) =>
      groupId.isNotEmpty ? groupId : recvId;

  /// 发送 Markdown 消息
  Future<PendingSend> sendMarkdownMessage({
    required String recvId,
    required String text,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) => sendPipeline.sendMarkdown(
    conversationId: conversationId,
    sourceId: _sourceId(recvId, groupId),
    sessionType: sessionType,
    text: text,
  );

  /// 发送 @ 提及消息
  Future<PendingSend> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String recvId,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) => sendPipeline.sendAtText(
    conversationId: conversationId,
    sourceId: _sourceId(recvId, groupId),
    sessionType: sessionType,
    text: text,
    atUserIds: atUserIds,
  );

  /// 搜索当前会话的本地消息
  Future<List<MessageSearchResult>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) => sendController.searchLocalMessages(
    conversationId: conversationId,
    keyword: keyword,
    offset: offset,
    count: count,
  );

  /// 转发消息（按 clientMsgId 原样转发，对齐 Go SDK ForwardMessage）
  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required ChatSessionType sessionType,
  }) => sendController.forwardMessage(
    clientMsgId: clientMsgId,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送图片消息
  Future<PendingSend> sendImageMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.sendImage(
    conversationId: conversationId,
    filePath: filePath,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送 URL 图片（如 GIF，内容已上传，不走 OSS）
  Future<PendingSend> sendImageMessageFromUrl({
    required String sourceUrl,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.sendImageFromUrl(
    conversationId: conversationId,
    sourceUrl: sourceUrl,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送视频消息
  Future<PendingSend> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required ChatSessionType sessionType,
    required int duration,
    required String conversationId,
  }) => sendPipeline.sendVideo(
    conversationId: conversationId,
    videoPath: videoPath,
    snapshotPath: snapshotPath,
    sourceId: sourceId,
    sessionType: sessionType,
    duration: duration,
  );

  /// 发送语音消息
  Future<PendingSend> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
    required int duration,
    required String conversationId,
  }) => sendPipeline.sendSound(
    conversationId: conversationId,
    filePath: filePath,
    sourceId: sourceId,
    sessionType: sessionType,
    duration: duration,
  );

  /// 发送文件消息
  Future<PendingSend> sendFileMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.sendFile(
    conversationId: conversationId,
    filePath: filePath,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送位置消息
  Future<PendingSend> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.sendLocation(
    conversationId: conversationId,
    description: description,
    latitude: latitude,
    longitude: longitude,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送表情消息
  Future<PendingSend> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.sendFace(
    conversationId: conversationId,
    index: index,
    data: data,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送名片消息
  Future<PendingSend> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.sendCard(
    conversationId: conversationId,
    userId: userId,
    nickname: nickname,
    faceUrl: faceUrl,
    ex: ex,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 发送引用消息
  Future<PendingSend> sendQuoteMessage({
    required String text,
    required String sourceId,
    required ChatSessionType sessionType,
    required ChatMessage quoted,
    required String conversationId,
  }) => sendPipeline.sendQuote(
    conversationId: conversationId,
    text: text,
    sourceId: sourceId,
    sessionType: sessionType,
    quoted: quoted,
  );

  /// 发送正在输入状态
  Future<void> sendTyping({
    required String sourceId,
    required ChatSessionType sessionType,
    required bool focus,
  }) => sendController.sendTyping(
    sourceId: sourceId,
    sessionType: sessionType,
    focus: focus,
  );

  /// 合并转发
  Future<void> sendMergerMessage({
    required List<String> clientMsgIds,
    required String sourceConversationId,
    required String title,
    required List<String> summaryList,
    required String sourceId,
    required ChatSessionType sessionType,
  }) => sendController.sendMergerMessage(
    clientMsgIds: clientMsgIds,
    sourceConversationId: sourceConversationId,
    title: title,
    summaryList: summaryList,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  /// 撤回消息
  Future<void> revokeMessage({
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  }) => sendController.revokeMessage(
    conversationId: conversationId,
    seq: seq,
    clientMsgId: clientMsgId,
    sessionType: sessionType,
  );

  /// 删除消息（本地+服务端）
  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  }) => sendController.deleteMessage(
    conversationId: conversationId,
    clientMsgId: clientMsgId,
  );
  Future<void> initialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) {
    return connectionController.initialize(
      wsUrl: wsUrl,
      apiBaseUrl: apiBaseUrl,
      userId: userId,
      imToken: imToken,
    );
  }

  void _onMessageEvent(MessageEvent event) {
    appLog.i('[MsgSvc] messageEvent: ${event.runtimeType}');
    event.when(
      newMessage: (conversationId, message) {
        eventApplier.appendIncomingMessage(conversationId, message);
      },
      offlineNewMessage: (conversationId, message) {
        eventApplier.appendIncomingMessage(conversationId, message);
      },
      onlineOnlyMessage: (conversationId, message) {
        eventApplier.appendIncomingMessage(conversationId, message);
      },
      revoked:
          (
            conversationId,
            seq,
            clientMsgId,
            revokerId,
            revokerRole,
            revokerNickname,
            revokeTime,
            sourceMessageSendTime,
            sourceMessageSendId,
            sourceMessageSenderNickname,
            sessionType,
            isAdminRevoke,
          ) {
            eventApplier.applyRevoked(
              conversationId: conversationId,
              seq: seq.toInt(),
              clientMsgId: clientMsgId,
              revokerNickname: revokerNickname,
              sourceMessageSenderNickname: sourceMessageSenderNickname,
            );
          },
      c2CReadReceipt: (receipts) => eventApplier.applyReadReceipts(receipts),
      deleted: (conversationId, clientMsgIds) =>
          eventApplier.applyDeleted(conversationId, clientMsgIds),
      sendFailed: (clientMsgId, error) =>
          eventApplier.applySendFailed(clientMsgId, error),
      uploadProgress: (clientMsgId, progress, totalSize, uploadedSize) =>
          eventApplier.applyUploadProgress(clientMsgId, progress),
    );
  }

  /// 重发一条发送失败的消息（沿用原 clientMsgId，不新增气泡）。
  Future<PendingSend> resendMessage({
    required ChatMessage message,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
  }) => sendPipeline.resend(
    conversationId: conversationId,
    message: message,
    sourceId: sourceId,
    sessionType: sessionType,
  );

  void removeMessage(String conversationId, String clientMsgId) =>
      historyController.removeMessage(conversationId, clientMsgId);

  /// 测试入口：等价于 SDK 消息事件流回调
  @visibleForTesting
  void onMessageEventForTest(MessageEvent event) => _onMessageEvent(event);

  Future<void> loadConversations() =>
      conversationController.loadConversations();

  Future<void> refreshConversations() =>
      conversationController.refreshConversations();

  void removeConversation(String conversationId) =>
      conversationController.removeConversation(conversationId);

  Future<void> disconnect() => connectionController.disconnect();

  Future<void> logout() async {
    try {
      await ref.read(imClientProvider).logout();
    } finally {
      // 对齐 Go SDK：登出后断开连接、关闭客户端并复位内存状态，确保切换账号时重新初始化
      await disconnect();
    }
  }

  /// 登出/切换账号后重置全部内存状态（对齐 Go SDK 登出后 SDK 回到初始状态）
  void resetState() {
    seenClientMsgIds.clear();
    updateState(MessageServiceState());
  }

  Future<void> markConversationMessageAsRead(String conversationId) =>
      conversationController.markConversationMessageAsRead(conversationId);

  Future<void> saveDraft(String conversationId, String draftText) =>
      conversationController.saveDraft(conversationId, draftText);

  Future<void> clearDraft(String conversationId) =>
      conversationController.clearDraft(conversationId);

  Future<void> toggleConversationPin(String conversationId, bool isPinned) =>
      conversationController.toggleConversationPin(conversationId, isPinned);

  Future<void> deleteConversation(String conversationId) =>
      conversationController.deleteConversation(conversationId);

  Future<void> hideConversation(String conversationId) =>
      conversationController.hideConversation(conversationId);

  Future<void> hideAllConversations() =>
      conversationController.hideAllConversations();

  Future<void> markAllConversationsAsRead() =>
      conversationController.markAllConversationsAsRead();
}
