import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;
import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;
import 'package:flutter_rust_demo/domain/models/topic_links.dart'
    show buildTopicLink;
import 'package:flutter_rust_demo/domain/models/topic_notification.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/domain/models/user_profile.dart'
    show UserProfile;
import 'package:flutter_rust_demo/generated/rust/domain/model/local.dart'
    show LocalConversation;
import 'package:flutter_rust_demo/generated/rust/core/event/events/connection.dart';
import 'package:flutter_rust_demo/generated/rust/core/event/events/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/core/event/events/friend.dart';
import 'package:flutter_rust_demo/generated/rust/core/event/events/group.dart';
import 'package:flutter_rust_demo/generated/rust/core/event/events/message.dart';
import 'package:flutter_rust_demo/generated/rust/domain/model/message.dart'
    show MessageInfo;
import 'package:flutter_rust_demo/generated/rust/core/event/events/user.dart';
import 'package:flutter_rust_demo/core/utils/app_logger.dart';
import 'package:flutter_rust_demo/providers/online_status_provider.dart';
import 'package:flutter_rust_demo/providers/account_profile_provider.dart';
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
import '../topics/topic_notification_controller.dart';
import 'topic_event_revision_provider.dart';

/// MessageService 的 Notifier
class MessageServiceNotifier extends Notifier<MessageServiceState> {
  final List<StreamSubscription<dynamic>> subscriptions = [];

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

  /// 僵尸「发送中」兜底：进入会话 / 回到前台时调用，把长时间无回执的消息标为失败
  void sweepStaleSendingMessages(String conversationId) => updateState(
    MessageServiceReducer.sweepStaleSending(
      currentState,
      conversationId,
      now: DateTime.now().millisecondsSinceEpoch,
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
        ref.read(accountProfileRepositoryProvider),
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
    String topicId = '',
  }) => sendPipeline.sendText(
    conversationId: conversationId,
    sourceId: _sourceId(recvId, groupId),
    sessionType: sessionType,
    text: text,
    topicId: topicId,
  );

  Future<PendingSend> sendTopicRootText({
    required String groupId,
    required String text,
    required String conversationId,
  }) => sendPipeline.sendTopicRootText(
    conversationId: conversationId,
    groupId: groupId,
    text: text,
  );

  Future<PendingSend> sendTopicRootMarkdown({
    required String groupId,
    required String text,
    required String conversationId,
  }) => sendPipeline.sendTopicRootMarkdown(
    conversationId: conversationId,
    groupId: groupId,
    text: text,
  );

  Future<PendingSend> sendTopicRootAtText({
    required String groupId,
    required String text,
    required List<String> atUserIds,
    required String conversationId,
  }) => sendPipeline.sendTopicRootAtText(
    conversationId: conversationId,
    groupId: groupId,
    text: text,
    atUserIds: atUserIds,
  );

  Future<PendingSend> sendTopicRootImage({
    required String groupId,
    required String filePath,
    required String conversationId,
  }) => sendPipeline.sendTopicRootImage(
    conversationId: conversationId,
    groupId: groupId,
    filePath: filePath,
  );

  Future<PendingSend> sendTopicRootImageFromUrl({
    required String groupId,
    required String sourceUrl,
    required String conversationId,
  }) => sendPipeline.sendTopicRootImageFromUrl(
    conversationId: conversationId,
    groupId: groupId,
    sourceUrl: sourceUrl,
  );

  Future<PendingSend> sendTopicRootVideo({
    required String groupId,
    required String videoPath,
    required String snapshotPath,
    required int duration,
    required String conversationId,
  }) => sendPipeline.sendTopicRootVideo(
    conversationId: conversationId,
    groupId: groupId,
    videoPath: videoPath,
    snapshotPath: snapshotPath,
    duration: duration,
  );

  Future<PendingSend> sendTopicRootSound({
    required String groupId,
    required String filePath,
    required int duration,
    required String conversationId,
  }) => sendPipeline.sendTopicRootSound(
    conversationId: conversationId,
    groupId: groupId,
    filePath: filePath,
    duration: duration,
  );

  Future<PendingSend> sendTopicRootFile({
    required String groupId,
    required String filePath,
    required String conversationId,
  }) => sendPipeline.sendTopicRootFile(
    conversationId: conversationId,
    groupId: groupId,
    filePath: filePath,
  );

  Future<PendingSend> sendTopicRootLocation({
    required String groupId,
    required String description,
    required double latitude,
    required double longitude,
    required String conversationId,
  }) => sendPipeline.sendTopicRootLocation(
    conversationId: conversationId,
    groupId: groupId,
    description: description,
    latitude: latitude,
    longitude: longitude,
  );

  Future<PendingSend> sendTopicRootCard({
    required String groupId,
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String conversationId,
  }) => sendPipeline.sendTopicRootCard(
    conversationId: conversationId,
    groupId: groupId,
    userId: userId,
    nickname: nickname,
    faceUrl: faceUrl,
    ex: ex,
  );

  Future<PendingSend> sendTopicRootQuote({
    required String groupId,
    required String text,
    required ChatMessage quoted,
    required String conversationId,
  }) => sendPipeline.sendTopicRootQuote(
    conversationId: conversationId,
    groupId: groupId,
    text: text,
    quoted: quoted,
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
    String topicId = '',
  }) => sendPipeline.sendMarkdown(
    conversationId: conversationId,
    sourceId: _sourceId(recvId, groupId),
    sessionType: sessionType,
    text: text,
    topicId: topicId,
  );

  /// 发送 @ 提及消息
  Future<PendingSend> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String recvId,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
    String topicId = '',
  }) => sendPipeline.sendAtText(
    conversationId: conversationId,
    sourceId: _sourceId(recvId, groupId),
    sessionType: sessionType,
    text: text,
    atUserIds: atUserIds,
    topicId: topicId,
  );

  /// 搜索当前会话的本地消息
  Future<List<MessageSearchResult>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
    List<int> messageTypes = const [],
    bool allowEmptyKeyword = false,
  }) => sendController.searchLocalMessages(
    conversationId: conversationId,
    keyword: keyword,
    offset: offset,
    count: count,
    messageTypes: messageTypes,
    allowEmptyKeyword: allowEmptyKeyword,
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
    String topicId = '',
  }) => sendPipeline.sendImage(
    conversationId: conversationId,
    filePath: filePath,
    sourceId: sourceId,
    sessionType: sessionType,
    topicId: topicId,
  );

  /// 发送 URL 图片（如 GIF，内容已上传，不走 OSS）
  Future<PendingSend> sendImageMessageFromUrl({
    required String sourceUrl,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendImageFromUrl(
    conversationId: conversationId,
    sourceUrl: sourceUrl,
    sourceId: sourceId,
    sessionType: sessionType,
    topicId: topicId,
  );

  /// 发送视频消息
  Future<PendingSend> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required ChatSessionType sessionType,
    required int duration,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendVideo(
    conversationId: conversationId,
    videoPath: videoPath,
    snapshotPath: snapshotPath,
    sourceId: sourceId,
    sessionType: sessionType,
    duration: duration,
    topicId: topicId,
  );

  /// 发送语音消息
  Future<PendingSend> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
    required int duration,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendSound(
    conversationId: conversationId,
    filePath: filePath,
    sourceId: sourceId,
    sessionType: sessionType,
    duration: duration,
    topicId: topicId,
  );

  /// 发送文件消息
  Future<PendingSend> sendFileMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendFile(
    conversationId: conversationId,
    filePath: filePath,
    sourceId: sourceId,
    sessionType: sessionType,
    topicId: topicId,
  );

  /// 发送位置消息
  Future<PendingSend> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendLocation(
    conversationId: conversationId,
    description: description,
    latitude: latitude,
    longitude: longitude,
    sourceId: sourceId,
    sessionType: sessionType,
    topicId: topicId,
  );

  /// 发送表情消息
  Future<PendingSend> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendFace(
    conversationId: conversationId,
    index: index,
    data: data,
    sourceId: sourceId,
    sessionType: sessionType,
    topicId: topicId,
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
    String topicId = '',
  }) => sendPipeline.sendCard(
    conversationId: conversationId,
    userId: userId,
    nickname: nickname,
    faceUrl: faceUrl,
    ex: ex,
    sourceId: sourceId,
    sessionType: sessionType,
    topicId: topicId,
  );

  /// 发送引用消息
  Future<PendingSend> sendQuoteMessage({
    required String text,
    required String sourceId,
    required ChatSessionType sessionType,
    required ChatMessage quoted,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendQuote(
    conversationId: conversationId,
    text: text,
    sourceId: sourceId,
    sessionType: sessionType,
    quoted: quoted,
    topicId: topicId,
  );

  Future<PendingSend> sendCustomMessage({
    required String data,
    required String extension,
    required String description,
    required String sourceId,
    required ChatSessionType sessionType,
    required String conversationId,
    String topicId = '',
  }) => sendPipeline.sendCustom(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    data: data,
    extension: extension,
    description: description,
    topicId: topicId,
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
        _appendIncoming(conversationId, message);
      },
      offlineNewMessage: (conversationId, message) {
        _appendIncoming(conversationId, message);
      },
      onlineOnlyMessage: (conversationId, message) {
        _appendIncoming(conversationId, message);
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

  void _appendIncoming(String conversationId, MessageInfo message) {
    if (message.contentType == 120 &&
        message.content.contains('openim.topic.event')) {
      final event = _topicEventData(message.content);
      final action = event?['action']?.toString() ?? '';
      final targetUserID = event?['targetUserID']?.toString() ?? '';
      final currentUserID = currentState.currentUserId;
      if (targetUserID.isNotEmpty &&
          currentUserID.isNotEmpty &&
          targetUserID != currentUserID) {
        return;
      }
      _recordTopicControlNotification(event);
      if (action == 'topic_read_changed' || action == 'group_topics_read') {
        ref.read(topicReadRevisionProvider.notifier).state++;
      } else {
        ref.read(topicEventRevisionProvider.notifier).state++;
      }
      return;
    }
    _recordTopicMessageNotification(message);
    eventApplier.appendIncomingMessage(conversationId, message);
  }

  void _recordTopicMessageNotification(MessageInfo message) {
    if (message.topicId.isEmpty) return;
    final currentUserID = currentState.currentUserId;
    if (message.sendId == currentUserID) return;
    final isRoot = message.topicId == message.clientMsgId;
    final isMention = _isTopicMention(message, currentUserID);
    final sender = message.senderNickname.isEmpty
        ? '群成员'
        : message.senderNickname;
    final body = _messageNotificationText(message);
    final type = isMention
        ? TopicNotificationType.mention
        : isRoot
        ? TopicNotificationType.newTopic
        : TopicNotificationType.reply;
    unawaited(
      ref
          .read(topicNotificationsProvider.notifier)
          .record(
            TopicNotification(
              id:
                  '${message.topicId}:${message.clientMsgId}:'
                  '$currentUserID:${type.wireValue}',
              groupId: message.groupId,
              topicId: message.topicId,
              actorId: message.sendId,
              actorName: sender,
              title: isMention
                  ? '$sender 在话题中提到了你'
                  : isRoot
                  ? '$sender 发布了话题'
                  : '$sender 回复了话题',
              body: body.isEmpty
                  ? isRoot
                        ? '有新话题，打开查看详情'
                        : '话题有新回复，打开查看详情'
                  : body,
              type: type,
              createdAt: message.sendTime > 0
                  ? message.sendTime
                  : DateTime.now().millisecondsSinceEpoch,
            ),
          ),
    );
  }

  bool _isTopicMention(MessageInfo message, String currentUserId) {
    if (currentUserId.isEmpty) return false;
    try {
      final content = jsonDecode(message.content);
      if (content is! Map) return false;
      final atUserList = content['atUserList'];
      if (atUserList is! List) return false;
      return atUserList.any(
        (value) =>
            value.toString() == currentUserId || value.toString() == 'AtAllTag',
      );
    } catch (_) {
      return false;
    }
  }

  String _messageNotificationText(MessageInfo message) {
    try {
      final content = jsonDecode(message.content);
      if (content is Map) {
        final text =
            content['content']?.toString() ?? content['text']?.toString() ?? '';
        return text.trim();
      }
    } catch (_) {}
    return '';
  }

  void _recordTopicControlNotification(Map<String, dynamic>? event) {
    if (event == null) return;
    final action = event['action']?.toString() ?? '';
    final groupID = event['groupID']?.toString() ?? '';
    final topicID = event['topicID']?.toString() ?? '';
    if (groupID.isEmpty || topicID.isEmpty) return;
    final occurredAt =
        (event['occurredAt'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final actorID = event['operatorID']?.toString() ?? '';
    final title = switch (action) {
      'topic_task_assigned' => '你收到一个话题任务',
      'topic_task_changed' => '话题任务状态已更新',
      'topic_state_changed' => '话题状态已更新',
      'topic_root_edited' => '话题内容已编辑',
      _ => '',
    };
    if (title.isEmpty) return;
    final type = switch (action) {
      'topic_task_assigned' => TopicNotificationType.taskAssigned,
      'topic_task_changed' => TopicNotificationType.taskChanged,
      'topic_state_changed' => TopicNotificationType.stateChanged,
      'topic_root_edited' => TopicNotificationType.rootEdited,
      _ => TopicNotificationType.stateChanged,
    };
    final currentUserID = currentState.currentUserId;
    final targetUserID = event['targetUserID']?.toString() ?? '';
    if (targetUserID.isNotEmpty &&
        currentUserID.isNotEmpty &&
        targetUserID != currentUserID) {
      return;
    }
    final recipientIDs = event['recipientIDs'];
    if (recipientIDs is List &&
        recipientIDs.isNotEmpty &&
        currentUserID.isNotEmpty &&
        !recipientIDs.any((value) => value.toString() == currentUserID)) {
      return;
    }
    final version = (event['version'] as num?)?.toInt() ?? occurredAt;
    final taskID = event['taskID']?.toString() ?? '';
    final notificationID = switch (action) {
      'topic_task_assigned' || 'topic_task_changed' =>
        '$topicID:$taskID:$version:$currentUserID:${type.wireValue}',
      _ => '$topicID:$action:$version:$currentUserID:${type.wireValue}',
    };
    final body = event['title']?.toString().trim().isNotEmpty == true
        ? event['title'].toString()
        : '打开话题查看最新状态';
    unawaited(
      ref
          .read(topicNotificationsProvider.notifier)
          .record(
            TopicNotification(
              id: notificationID,
              groupId: groupID,
              topicId: topicID,
              actorId: actorID,
              actorName: '',
              title: title,
              body: body,
              type: type,
              createdAt: occurredAt,
            ),
          ),
    );
    if (ref.read(appLifecycleServiceProvider).isBackground.value) {
      unawaited(
        ref
            .read(localNotificationServiceProvider)
            .showMessageNotification(
              title: title,
              body: body,
              payload: buildTopicLink(groupId: groupID, topicId: topicID),
            ),
      );
    }
  }

  Map<String, dynamic>? _topicEventData(String content) {
    try {
      final outer = jsonDecode(content);
      if (outer is! Map) return null;
      final raw = outer['data'];
      if (raw is! String) return null;
      final event = jsonDecode(raw);
      return event is Map ? Map<String, dynamic>.from(event) : null;
    } catch (_) {
      return null;
    }
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

  /// 同步失败后的手动重试。
  Future<void> retrySyncConversations() => conversationController.retrySync();

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
