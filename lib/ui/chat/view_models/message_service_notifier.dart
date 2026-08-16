import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/generated/rust/ffi/client.dart' as fb;
import 'package:flutter_rust_demo/generated/rust/ffi/message_advanced.dart'
    show sendMessage;
import 'package:flutter_rust_demo/generated/rust/model/msg_struct.dart'
    show MsgStruct;
import 'package:flutter_rust_demo/generated/rust/constant/enums.dart';
import 'package:flutter_rust_demo/generated/rust/model/user.dart' show UserInfo;
import 'package:flutter_rust_demo/generated/rust/model/local.dart'
    show LocalChatLog, LocalConversation;
import 'package:flutter_rust_demo/generated/rust/model/message.dart'
    show MessageInfo;
import 'package:flutter_rust_demo/domain/extensions/message_ext.dart'
    show MessageInfoExt, sortMessagesByTime;
import 'package:flutter_rust_demo/generated/rust/event/events/connection.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/friend.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/group.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/message.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/user.dart';
import 'package:flutter_rust_demo/ui/core/utils/app_logger.dart';
import 'package:flutter_rust_demo/data/services/login_storage.dart';
import 'package:flutter_rust_demo/data/services/app_lifecycle_service.dart';
import 'package:flutter_rust_demo/data/services/local_notification_service.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'message_service_connection_controller.dart';
import 'message_service_conversation_controller.dart';
import 'message_service_helpers.dart';
import 'message_service_reducer.dart';
import 'message_service_social_controller.dart';

/// MessageService 的 Notifier
class MessageServiceNotifier extends Notifier<MessageServiceState> {
  fb.OpenImBridgeClient? client;
  final List<StreamSubscription<dynamic>> subscriptions = [];

  /// 已处理的 clientMsgId 集合，防止同一消息被重复添加到列表
  final Set<String> seenClientMsgIds = {};

  MessageServiceConnectionController? _connectionController;
  MessageServiceConversationController? _conversationController;
  MessageServiceSocialController? _socialController;

  @override
  MessageServiceState build() => const MessageServiceState();

  MessageServiceConnectionController get connectionController =>
      _connectionController ??= MessageServiceConnectionController(this);

  MessageServiceConversationController get conversationController =>
      _conversationController ??= MessageServiceConversationController(this);

  MessageServiceSocialController get socialController =>
      _socialController ??= MessageServiceSocialController(this);

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

  void applyGroupReadReceipts(List<GroupReadReceipt> receipts) =>
      socialController.applyGroupReadReceipts(receipts);

  void applyConversationEvent(List<LocalConversation> incoming) =>
      _applyConversationEvent(incoming);

  /// 获取指定会话的消息列表
  List<MessageInfo> getMessages(String conversationId) {
    return List.unmodifiable(
      sortMessagesByTime(state.messages[conversationId] ?? const []),
    );
  }

  /// 将发送结果写入全局消息状态（替代已移除的 messageSent 事件）
  void upsertSentMessage(String conversationId, MsgStruct result) {
    final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    final idx = list.indexWhere((m) => m.clientMsgId == result.clientMsgId);
    final msgInfo = MessageInfo(
      clientMsgId: result.clientMsgId,
      serverMsgId: result.serverMsgId,
      sendId: result.sendId,
      recvId: result.recvId,
      groupId: result.groupId,
      senderPlatformId: result.senderPlatformId,
      senderNickname: result.senderNickname,
      senderFaceUrl: result.senderFaceUrl,
      sessionType: result.sessionType,
      msgFrom: result.msgFrom,
      contentType: result.contentType,
      content: result.content,
      seq: result.seq,
      sendTime: normalizeMessageSendTime(result.sendTime.toInt()),
      createTime: result.createTime > 0
          ? result.createTime
          : normalizeMessageSendTime(result.sendTime.toInt()),
      status: result.status,
      isRead: false,
      attachedInfo: '',
      ex: '',
    );
    if (idx >= 0) {
      list[idx] = msgInfo;
    } else {
      seenClientMsgIds.add(result.clientMsgId);
      list.add(msgInfo);
    }
    newMessages[conversationId] = List<MessageInfo>.from(list);
    state = state.copyWith(messages: newMessages);
  }

  /// 获取指定用户资料（命中缓存时）
  UserInfo? getUserProfile(String userId) => state.userProfiles[userId];

  /// 拉取当前登录用户资料（通过批量接口 getUsersInfo，走缓存）并更新内存缓存
  Future<UserInfo?> refreshLoginUserProfile() async {
    if (client == null || state.currentUserId.isEmpty) return null;
    try {
      final list = await repository.getUsersInfo([state.currentUserId]);
      final profile = list.isNotEmpty ? list.first : null;
      if (profile != null) {
        final newUserProfiles = Map<String, UserInfo>.from(state.userProfiles);
        newUserProfiles[profile.userId] = profile;
        state = state.copyWith(
          loginUserProfile: profile,
          userProfiles: newUserProfiles,
        );
      }
      return profile;
    } catch (e) {
      appLog.e('[MessageService] 拉取当前用户资料失败: $e');
      return null;
    }
  }

  /// 批量预加载用户资料
  Future<void> preloadUserProfiles(List<String> userIds) async {
    if (client == null || userIds.isEmpty) return;
    final uniq = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uniq.isEmpty) return;
    try {
      final list = await repository.getUsersInfo(uniq);
      final newUserProfiles = Map<String, UserInfo>.from(state.userProfiles);
      for (final p in list) {
        newUserProfiles[p.userId] = p;
      }
      state = state.copyWith(userProfiles: newUserProfiles);
    } catch (e) {
      appLog.w('[MessageService] 批量拉取用户资料失败: $e');
    }
  }

  Future<UserInfo?> updateLoginUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
    int? globalRecvMsgOpt,
  }) async {
    if (client == null) {
      try {
        appLog.i('[MessageService] client 为 null，尝试重新初始化');
        final credentials = await LoginStorage.loadCredentials();
        if (credentials != null) {
          appLog.i('[MessageService] 找到保存的凭证，尝试重新初始化');
          await initialize(
            userId: credentials.userId,
            imToken: credentials.imToken,
          );
        } else {
          appLog.w('[MessageService] 没有找到保存的凭证，无法重新初始化');
        }
      } catch (e) {
        appLog.e('[MessageService] 重新初始化失败: $e');
      }
    }

    if (client == null) return null;

    try {
      await repository.updateUserProfile(
        nickname: nickname,
        faceUrl: faceUrl,
        ex: ex,
      );
      return await refreshLoginUserProfile();
    } catch (e) {
      appLog.e('[MessageService] 更新当前用户资料失败: $e');
      return null;
    }
  }

  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    String startClientMsgId = '',
  }) async {
    if (client == null) return false;

    try {
      appLog.i(
        '[MSG] Service 加载历史消息: conv=$conversationId count=$count start=$startClientMsgId',
      );
      final result = await repository.getHistoryMessages(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId,
        count: count,
      );

      if (result.messages.isEmpty) {
        appLog.i(
          '[MSG] Service 空页: conv=$conversationId isEnd=${result.isEnd}',
        );
        return !result.isEnd;
      }

      final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
      final currentMessages = newMessages.putIfAbsent(conversationId, () => []);
      final beforeCount = currentMessages.length;

      // result.messages 已经是 List<MessageInfo>，直接使用
      currentMessages.insertAll(0, result.messages);

      final seenIds = <String>{};
      final merged = currentMessages
          .where((msg) => seenIds.add(msg.clientMsgId))
          .toList();
      final dedupRemoved = beforeCount + result.messages.length - merged.length;
      newMessages[conversationId] = merged;

      final firstSeq = result.messages.isNotEmpty
          ? result.messages.first.seq
          : 0;
      final lastSeq = result.messages.isNotEmpty ? result.messages.last.seq : 0;

      appLog.i(
        '[MSG] Service 加载完成: conv=$conversationId start=$startClientMsgId '
        'new=${result.messages.length} firstSeq=$firstSeq lastSeq=$lastSeq '
        'dedupRemoved=$dedupRemoved isEnd=${result.isEnd}',
      );

      state = state.copyWith(messages: newMessages);

      return !result.isEnd;
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载历史消息失败: $e');
      rethrow;
    }
  }

  Future<MsgStruct> sendTextMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    if (recvId.trim().isEmpty && groupId.trim().isEmpty) {
      throw ArgumentError('recvId 与 groupId 至少填一个');
    }

    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return repository.sendTextMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送 Markdown 消息
  Future<MsgStruct> sendMarkdownMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return repository.sendMarkdownMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送 @ 提及消息
  Future<MsgStruct> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String recvId,
    required SessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return repository.sendAtTextMessage(
      text: text,
      atUserIds: atUserIds,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 搜索当前会话的本地消息
  Future<List<LocalChatLog>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    if (keyword.trim().isEmpty) return const [];
    return repository.searchLocalMessages(
      conversationId: conversationId,
      keyword: keyword,
      offset: offset,
      count: count,
    );
  }

  /// 转发消息（按 clientMsgId 原样转发，对齐 Go SDK ForwardMessage）
  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    await repository.forwardMessage(
      clientMsgId: clientMsgId,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送图片消息
  Future<MsgStruct> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendImageMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送 URL 图片（如 GIF，内容已上传，不走 OSS）
  Future<MsgStruct> sendImageMessageFromUrl({
    required String sourceUrl,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendImageMessageFromUrl(
      sourceUrl: sourceUrl,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送视频消息
  Future<MsgStruct> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendVideoMessage(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  /// 发送语音消息
  Future<MsgStruct> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendSoundMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  /// 发送文件消息
  Future<MsgStruct> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendFileMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送位置消息
  Future<MsgStruct> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendLocationMessage(
      description: description,
      latitude: latitude,
      longitude: longitude,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送表情消息
  Future<MsgStruct> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendFaceMessage(
      index: index,
      data: data,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送名片消息
  Future<MsgStruct> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendCardMessage(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送引用消息
  Future<MsgStruct> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    return repository.sendQuoteMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
      quoteText: quoteText,
      quoteClientMsgId: quoteClientMsgId,
      quoteSendId: quoteSendId,
      quoteSendTime: quoteSendTime,
    );
  }

  /// 撤回消息
  Future<void> revokeMessage({
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    await repository.revokeMessage(
      conversationId: conversationId,
      userId: state.currentUserId,
      seq: seq,
      clientMsgId: clientMsgId,
      sessionType: sessionType,
    );
  }

  /// 删除消息（本地+服务端）
  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
    await repository.deleteMessage(
      conversationId: conversationId,
      clientMsgId: clientMsgId,
    );
  }

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
        _appendIncomingMessage(conversationId, message);
      },
      offlineNewMessage: (conversationId, message) {
        _appendIncomingMessage(conversationId, message);
      },
      onlineOnlyMessage: (conversationId, message) {
        _appendIncomingMessage(conversationId, message);
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
            _applyRevoked(
              conversationId: conversationId,
              seq: seq.toInt(),
              clientMsgId: clientMsgId,
              revokerNickname: revokerNickname,
              sourceMessageSenderNickname: sourceMessageSenderNickname,
            );
          },
      c2CReadReceipt: (receipts) => _applyReadReceipts(receipts),
      deleted: (conversationId, clientMsgIds) =>
          _applyDeleted(conversationId, clientMsgIds),
      sendFailed: (clientMsgId, error) => _applySendFailed(clientMsgId, error),
      uploadProgress: (clientMsgId, progress, totalSize, uploadedSize) =>
          _applyUploadProgress(clientMsgId, progress),
    );
  }

  /// 重发一条发送失败的消息（Rust 侧会生成新 clientMsgId）。
  Future<MsgStruct> resendMessage({
    required MessageInfo message,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (client == null) throw StateError('客户端未初始化');
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
    return sendMessage(
      msgStruct: msgStruct,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 移除指定消息（用于重发成功后替换旧的失败消息）。
  void removeMessage(String conversationId, String clientMsgId) {
    state = MessageServiceReducer.removeMessage(
      state,
      conversationId,
      clientMsgId,
    );
  }

  void _applyRevoked({
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required String revokerNickname,
    required String sourceMessageSenderNickname,
  }) {
    state = MessageServiceReducer.applyRevoked(
      state,
      conversationId: conversationId,
      seq: seq,
      clientMsgId: clientMsgId,
      revokerNickname: revokerNickname,
      sourceMessageSenderNickname: sourceMessageSenderNickname,
    );
  }

  void _applyReadReceipts(List<MessageReceipt> receipts) {
    state = MessageServiceReducer.applyReadReceipts(state, receipts);
  }

  void _applyDeleted(String conversationId, List<String> clientMsgIds) {
    state = MessageServiceReducer.applyDeleted(
      state,
      conversationId,
      clientMsgIds,
    );
  }

  void _applySendFailed(String clientMsgId, String error) {
    appLog.w('[MsgSvc] sendFailed: clientMsgId=$clientMsgId error=$error');
    state = MessageServiceReducer.applySendFailed(state, clientMsgId);
  }

  void _applyUploadProgress(String clientMsgId, int progress) {
    state = MessageServiceReducer.applyUploadProgress(
      state,
      clientMsgId,
      progress,
    );
  }

  /// 事件驱动更新会话列表（对齐官方 Demo：直接用 ConversationChanged 携带的数据更新，不重载 DB）
  void _applyConversationEvent(List<LocalConversation> incoming) {
    state = MessageServiceReducer.applyConversationEvent(state, incoming);
  }

  /// 测试入口：等价于 SDK 消息事件流回调
  @visibleForTesting
  void onMessageEventForTest(MessageEvent event) => _onMessageEvent(event);

  /// 收到新消息事件时直接追加到对应会话列表（对齐 Go SDK OnRecvNewMessage 驱动 UI 更新）
  void _appendIncomingMessage(String conversationId, MessageInfo message) {
    if (AppLifecycleService.instance.isBackground.value) {
      unawaited(
        LocalNotificationService.instance.showMessageNotification(
          title: message.senderNickname.isNotEmpty
              ? message.senderNickname
              : '新消息',
          body: message.displayText,
        ),
      );
    }
    state = MessageServiceReducer.appendIncomingMessage(
      state,
      conversationId,
      message,
    );
  }

  Future<void> loadConversations() =>
      conversationController.loadConversations();

  Future<void> refreshConversations() =>
      conversationController.refreshConversations();

  void removeConversation(String conversationId) =>
      conversationController.removeConversation(conversationId);

  Future<void> disconnect() => connectionController.disconnect();

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

  Future<void> markAllConversationsAsRead() =>
      conversationController.markAllConversationsAsRead();
}
