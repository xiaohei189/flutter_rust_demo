import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/ui/core/extensions/conversation_extensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/src/rust/ffi/client.dart' as fb;
import 'package:flutter_rust_demo/src/rust/ffi/message_advanced.dart'
    show sendMessage;
import 'package:flutter_rust_demo/src/rust/model/msg_struct.dart'
    show MsgStruct;
import 'package:flutter_rust_demo/src/rust/client/config.dart';
import 'package:flutter_rust_demo/src/rust/constant/enums.dart';
import 'package:flutter_rust_demo/src/rust/model/user.dart' show UserInfo;
import 'package:flutter_rust_demo/src/rust/model/local.dart'
    show LocalChatLog, LocalConversation;
import 'package:flutter_rust_demo/src/rust/ffi/ffi_init.dart' show initLogger;
import 'package:flutter_rust_demo/src/rust/model/message.dart' show MessageInfo;
import 'package:flutter_rust_demo/domain/models/message_ext.dart'
    show MessageInfoExt, sortMessagesByTime;
import 'package:flutter_rust_demo/src/rust/event/events/connection.dart';
import 'package:flutter_rust_demo/src/rust/event/events/conversation.dart';
import 'package:flutter_rust_demo/src/rust/event/events/friend.dart';
import 'package:flutter_rust_demo/src/rust/event/events/group.dart';
import 'package:flutter_rust_demo/src/rust/event/events/message.dart';
import 'package:flutter_rust_demo/src/rust/event/events/user.dart';
import 'package:flutter_rust_demo/ui/core/utils/app_logger.dart';
import 'package:flutter_rust_demo/ui/core/utils/login_storage.dart';
import 'package:flutter_rust_demo/data/services/navigation_service.dart';
import 'package:flutter_rust_demo/data/services/app_lifecycle_service.dart';
import 'package:flutter_rust_demo/data/services/local_notification_service.dart';
import 'package:flutter_rust_demo/data/services/online_status_service.dart';

/// MessageService 的状态类
class MessageServiceState {
  final bool isConnected;
  final bool isSyncingConversations;
  final int syncProgress;
  final String currentUserId;
  final List<LocalConversation> conversations;
  final Map<String, List<MessageInfo>> messages;
  final Map<String, UserInfo> userProfiles;
  final UserInfo? loginUserProfile;
  final bool isInitializing;
  final int totalUnreadCount;
  final int friendRevision;
  final int groupRevision;

  /// 各会话当前正在输入的用户（conversationId -> userId）
  final Map<String, String> typingUsers;

  /// 各消息上传进度（clientMsgId -> 0-100）
  final Map<String, int> uploadProgress;

  /// 群聊已读统计（msgId -> 回执）
  final Map<String, GroupReadReceipt> groupReadReceipts;

  const MessageServiceState({
    this.isConnected = false,
    this.isSyncingConversations = false,
    this.syncProgress = 0,
    this.currentUserId = '',
    this.conversations = const [],
    this.messages = const {},
    this.userProfiles = const {},
    this.loginUserProfile,
    this.isInitializing = false,
    this.totalUnreadCount = 0,
    this.friendRevision = 0,
    this.groupRevision = 0,
    this.typingUsers = const {},
    this.uploadProgress = const {},
    this.groupReadReceipts = const {},
  });

  MessageServiceState copyWith({
    bool? isConnected,
    bool? isSyncingConversations,
    int? syncProgress,
    String? currentUserId,
    List<LocalConversation>? conversations,
    Map<String, List<MessageInfo>>? messages,
    Map<String, UserInfo>? userProfiles,
    UserInfo? loginUserProfile,
    bool? isInitializing,
    int? totalUnreadCount,
    int? friendRevision,
    int? groupRevision,
    Map<String, String>? typingUsers,
    Map<String, int>? uploadProgress,
    Map<String, GroupReadReceipt>? groupReadReceipts,
  }) {
    return MessageServiceState(
      isConnected: isConnected ?? this.isConnected,
      isSyncingConversations:
          isSyncingConversations ?? this.isSyncingConversations,
      syncProgress: syncProgress ?? this.syncProgress,
      currentUserId: currentUserId ?? this.currentUserId,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      userProfiles: userProfiles ?? this.userProfiles,
      loginUserProfile: loginUserProfile ?? this.loginUserProfile,
      isInitializing: isInitializing ?? this.isInitializing,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      friendRevision: friendRevision ?? this.friendRevision,
      groupRevision: groupRevision ?? this.groupRevision,
      typingUsers: typingUsers ?? this.typingUsers,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      groupReadReceipts: groupReadReceipts ?? this.groupReadReceipts,
    );
  }
}

/// MessageService 的 StateNotifier
class MessageServiceNotifier extends StateNotifier<MessageServiceState> {
  fb.OpenImBridgeClient? _client;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final MessageRepository _repository;

  /// 已处理的 clientMsgId 集合，防止同一消息被重复添加到列表
  final Set<String> _seenClientMsgIds = {};

  MessageServiceNotifier({required MessageRepository repository})
      : _repository = repository,
        super(const MessageServiceState());

  /// 获取客户端实例
  fb.OpenImBridgeClient? get client => _client;

  /// 对外只读状态快照（避免外部访问 StateNotifier 的 protected state）
  MessageServiceState get currentState => state;

  /// 将 sendTime 规范化为毫秒（自动检测秒/毫秒）
  static int _normalizeSendTime(int t) {
    if (t <= 0) return DateTime.now().millisecondsSinceEpoch;
    // 如果小于 2000-01-01 的毫秒时间戳，认为是秒级
    if (t < 946684800000) return t * 1000;
    return t;
  }

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
      sendTime: _normalizeSendTime(result.sendTime.toInt()),
      createTime: result.createTime > 0
          ? result.createTime
          : _normalizeSendTime(result.sendTime.toInt()),
      status: result.status,
      isRead: false,
      attachedInfo: '',
      ex: '',
    );
    if (idx >= 0) {
      list[idx] = msgInfo;
    } else {
      _seenClientMsgIds.add(result.clientMsgId);
      list.add(msgInfo);
    }
    newMessages[conversationId] = List<MessageInfo>.from(list);
    state = state.copyWith(messages: newMessages);
  }

  /// 获取指定用户资料（命中缓存时）
  UserInfo? getUserProfile(String userId) => state.userProfiles[userId];

  /// 拉取当前登录用户资料（通过批量接口 getUsersInfo，走缓存）并更新内存缓存
  Future<UserInfo?> refreshLoginUserProfile() async {
    if (_client == null || state.currentUserId.isEmpty) return null;
    try {
      final list = await _repository.getUsersInfo([state.currentUserId]);
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
    if (_client == null || userIds.isEmpty) return;
    final uniq = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uniq.isEmpty) return;
    try {
      final list = await _repository.getUsersInfo(uniq);
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
    if (_client == null) {
      try {
        appLog.i('[MessageService] _client 为 null，尝试重新初始化');
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

    if (_client == null) return null;

    try {
      await _repository.updateUserProfile(
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
    if (_client == null) return false;

    try {
      appLog.i(
        '[MSG] Service 加载历史消息: conv=$conversationId count=$count start=$startClientMsgId',
      );
      final result = await _repository.getHistoryMessages(
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
    if (_client == null) throw StateError('客户端未初始化');
    if (recvId.trim().isEmpty && groupId.trim().isEmpty) {
      throw ArgumentError('recvId 与 groupId 至少填一个');
    }

    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return _repository.sendTextMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return _repository.sendMarkdownMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return _repository.sendAtTextMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    if (keyword.trim().isEmpty) return const [];
    return _repository.searchLocalMessages(
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
    if (_client == null) throw StateError('客户端未初始化');
    await _repository.forwardMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendImageMessage(
      filePath: filePath,
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendVideoMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendSoundMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendFileMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendLocationMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendFaceMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendCardMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    return _repository.sendQuoteMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    await _repository.revokeMessage(
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
    if (_client == null) throw StateError('客户端未初始化');
    await _repository.deleteMessage(
      conversationId: conversationId,
      clientMsgId: clientMsgId,
    );
  }

  Future<void> initialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) async {
    if (_client != null && state.isConnected) {
      appLog.i('ℹ️ 客户端已连接，跳过重复初始化（热更新场景）');
      return;
    }

    if (state.isInitializing) {
      appLog.w('⚠️ 初始化正在进行中，跳过重复调用');
      return;
    }

    state = state.copyWith(isInitializing: true);
    appLog.i('[MessageService] initialize 开始');
    try {
      // 关闭已有客户端（热重启或重复登录场景），避免两个实例同时存在导致被踢
      if (_client != null) {
        appLog.i('[MessageService] 关闭已有客户端，重新初始化');
        for (final s in _subscriptions) {
          await s.cancel();
        }
        _subscriptions.clear();
        try {
          await _client!.disconnect();
        } catch (e) {
          appLog.w('[MessageService] 关闭旧客户端失败: $e');
        }
        _client = null;
        OnlineStatusService.instance.setClient(null);
      }

      appLog.i('[MessageService] 初始化日志和 SDK 客户端...');
      await initLogger(logLevel: 'info,rust_lib_flutter_rust_demo=debug');

      final String resolvedUserId;
      final String resolvedImToken;
      if (userId != null &&
          userId.isNotEmpty &&
          imToken != null &&
          imToken.isNotEmpty) {
        resolvedUserId = userId;
        resolvedImToken = imToken;
        appLog.i('[MessageService] 用户ID: $resolvedUserId');
      } else {
        throw StateError('缺少 userId 或 imToken，请先登录');
      }

      state = state.copyWith(currentUserId: resolvedUserId);

      final docDir = await getApplicationDocumentsDirectory();
      final dataDir = '${docDir.path}/openim_data';
      _client = await fb.OpenImBridgeClient.newInstance(
        config: ClientConfig(
          userId: resolvedUserId,
          token: resolvedImToken,
          platformId: 5,
          wsUrl: wsUrl,
          apiBaseUrl: apiBaseUrl!,
          dataDir: dataDir,
        ),
      );
      OnlineStatusService.instance.setClient(_client);
      unawaited(_loadConversations());

      _subscriptions.add(
        _client!.connectionStream().listen(_onConnectionEvent),
      );
      _subscriptions.add(
        _client!.conversationStream().listen(_onConversationEvent),
      );
      _subscriptions.add(_client!.friendStream().listen(_onFriendEvent));
      _subscriptions.add(_client!.groupStream().listen(_onGroupEvent));
      _subscriptions.add(_client!.messageStream().listen(_onMessageEvent));
      _subscriptions.add(_client!.userStream().listen(_onUserEvent));
      appLog.i('[MessageService] 6 模块事件流已注册');

      state = state.copyWith(isConnected: true);
      appLog.i('✅ 客户端连接成功');

      // 用户资料后台加载，不阻塞进入主页
      unawaited(refreshLoginUserProfile());

      // 再次从 DB 加载会话，确保最新
      _loadConversations();
    } catch (e) {
      appLog.e('❌ 初始化失败: $e');
      state = state.copyWith(isConnected: false);
      rethrow;
    } finally {
      state = state.copyWith(isInitializing: false);
    }
  }

  void _onConnectionEvent(ConnectionEvent event) {
    appLog.i('[MsgSvc] _onConnectionEvent: ${event.runtimeType}');
    event.maybeWhen(
      connected: () {
        appLog.i('[MsgSvc] connected!');
        state = state.copyWith(isConnected: true);
        _loadConversations();
      },
      kickedOffline: (_) => state = state.copyWith(isConnected: false),
      tokenExpired: () {
        state = state.copyWith(isConnected: false);
        LoginStorage.clearCredentials().catchError((_) {});
        NavigationService.instance.goToLogin();
      },
      orElse: () {},
    );
  }

  void _onConversationEvent(ConversationEvent event) {
    event.maybeWhen(
      syncStarted: (_) =>
          state = state.copyWith(isSyncingConversations: true, syncProgress: 0),
      syncFinished: (_) {
        state = state.copyWith(
          isSyncingConversations: false,
          syncProgress: 100,
        );
        _loadConversations();
      },
      syncProgress: (p, _) =>
          state = state.copyWith(isSyncingConversations: true, syncProgress: p),
      totalUnreadCountChanged: (c) {
        appLog.i('[MsgSvc] totalUnreadCountChanged: $c');
        state = state.copyWith(totalUnreadCount: c);
      },
      changed: (conversations) {
        appLog.i('[MsgSvc] conversationChanged: count=${conversations.length}');
        _applyConversationEvent(conversations);
      },
      new_: (conversations) {
        appLog.i('[MsgSvc] newConversation: count=${conversations.length}');
        _applyConversationEvent(conversations);
      },
      deleted: (_) => appLog.i('[MsgSvc] conversationDeleted'),
      userInputStatusChanged: (cid, uid, platformIds) {
        appLog.i(
          '[MsgSvc] typing: conv=$cid user=$uid platforms=${platformIds.length}',
        );
        final typingUsers = Map<String, String>.from(state.typingUsers);
        if (platformIds.isNotEmpty) {
          typingUsers[cid] = uid;
        } else {
          typingUsers.remove(cid);
        }
        state = state.copyWith(typingUsers: typingUsers);
      },
      syncFailed: (reinstalled, e) =>
          appLog.i('[MsgSvc] syncFailed: reinstalled=$reinstalled error=$e'),
      orElse: () {},
    );
  }

  void _onFriendEvent(FriendEvent event) {
    appLog.i('[MsgSvc] friendEvent: ${event.runtimeType}');
    state = state.copyWith(friendRevision: state.friendRevision + 1);
  }

  void _onGroupEvent(GroupEvent event) {
    appLog.i('[MsgSvc] groupEvent: ${event.runtimeType}');
    event.maybeWhen(
      groupReadReceipt: (receipts) => _applyGroupReadReceipts(receipts),
      orElse: () {
        state = state.copyWith(groupRevision: state.groupRevision + 1);
      },
    );
  }

  void _applyGroupReadReceipts(List<GroupReadReceipt> receipts) {
    if (receipts.isEmpty) return;
    final updated = Map<String, GroupReadReceipt>.from(state.groupReadReceipts);
    for (final receipt in receipts) {
      updated[receipt.msgId] = receipt;
    }
    state = state.copyWith(
      groupReadReceipts: updated,
      groupRevision: state.groupRevision + 1,
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
    if (_client == null) throw StateError('客户端未初始化');
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
    final current = state.messages[conversationId];
    if (current == null) return;
    final updated = current.where((m) => m.clientMsgId != clientMsgId).toList();
    if (updated.length == current.length) return;
    final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
    newMessages[conversationId] = updated;
    state = state.copyWith(messages: newMessages);
  }

  void _applyRevoked({
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required String revokerNickname,
    required String sourceMessageSenderNickname,
  }) {
    final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
    final list = newMessages[conversationId];
    if (list == null || list.isEmpty) return;

    final nickname = revokerNickname.isNotEmpty
        ? revokerNickname
        : sourceMessageSenderNickname;
    final revokedContent = jsonEncode({
      'content': '${nickname.isEmpty ? '对方' : nickname} 撤回了一条消息',
      'revokerNickname': nickname,
    });
    final idx = list.indexWhere(
      (m) => m.clientMsgId == clientMsgId || m.seq.toInt() == seq,
    );
    if (idx >= 0) {
      final updated = List<MessageInfo>.from(list);
      updated[idx] = updated[idx].copyMessageInfo(
        content: revokedContent,
        contentType: 2101,
        status: 4,
      );
      newMessages[conversationId] = updated;
      state = state.copyWith(messages: newMessages);
    }
  }

  void _applyReadReceipts(List<MessageReceipt> receipts) {
    final msgIds = receipts.expand((r) => r.msgIds).toSet();
    if (msgIds.isEmpty) return;

    final newMessages = <String, List<MessageInfo>>{};
    var changed = false;
    for (final entry in state.messages.entries) {
      final list = entry.value;
      if (!list.any((m) => msgIds.contains(m.clientMsgId))) {
        newMessages[entry.key] = list;
        continue;
      }
      newMessages[entry.key] = list
          .map(
            (m) => msgIds.contains(m.clientMsgId)
                ? m.copyMessageInfo(isRead: true)
                : m,
          )
          .toList();
      changed = true;
    }
    if (changed) {
      state = state.copyWith(messages: newMessages);
    }
  }

  void _applyDeleted(String conversationId, List<String> clientMsgIds) {
    final ids = clientMsgIds.toSet();
    final current = state.messages[conversationId];
    if (current == null || ids.isEmpty) return;
    final updated = current.where((m) => !ids.contains(m.clientMsgId)).toList();
    if (updated.length == current.length) return;
    final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
    newMessages[conversationId] = updated;
    state = state.copyWith(messages: newMessages);
  }

  void _applySendFailed(String clientMsgId, String error) {
    appLog.w('[MsgSvc] sendFailed: clientMsgId=$clientMsgId error=$error');
    final newMessages = <String, List<MessageInfo>>{};
    var changed = false;
    for (final entry in state.messages.entries) {
      final list = entry.value;
      final idx = list.indexWhere((m) => m.clientMsgId == clientMsgId);
      if (idx < 0) {
        newMessages[entry.key] = list;
        continue;
      }
      final updated = List<MessageInfo>.from(list);
      updated[idx] = updated[idx].copyMessageInfo(status: 3);
      newMessages[entry.key] = updated;
      changed = true;
    }
    if (changed) {
      final progress = Map<String, int>.from(state.uploadProgress)
        ..remove(clientMsgId);
      state = state.copyWith(messages: newMessages, uploadProgress: progress);
    }
  }

  void _applyUploadProgress(String clientMsgId, int progress) {
    final nextProgress = progress.clamp(0, 100);
    final uploadProgress = Map<String, int>.from(state.uploadProgress);
    if (nextProgress >= 100) {
      uploadProgress.remove(clientMsgId);
    } else {
      uploadProgress[clientMsgId] = nextProgress;
    }
    state = state.copyWith(uploadProgress: uploadProgress);
  }

  /// 事件驱动更新会话列表（对齐官方 Demo：直接用 ConversationChanged 携带的数据更新，不重载 DB）
  void _applyConversationEvent(List<LocalConversation> incoming) {
    if (incoming.isEmpty) return;
    final newConversations = List<LocalConversation>.from(state.conversations);
    for (final conv in incoming) {
      final index = newConversations.indexWhere(
        (c) => c.conversationId == conv.conversationId,
      );
      if (index >= 0) {
        final existing = newConversations[index];
        final existingTime = existing.latestMsgSendTime.toInt();
        final convTime = conv.latestMsgSendTime.toInt();
        final useExisting =
            existing.latestMsg.isNotEmpty && existingTime >= convTime;
        newConversations[index] = LocalConversation(
          conversationId: conv.conversationId,
          conversationType: conv.conversationType,
          userId: conv.userId,
          groupId: conv.groupId,
          showName: conv.showName.isNotEmpty
              ? conv.showName
              : existing.showName,
          faceUrl: conv.faceUrl.isNotEmpty ? conv.faceUrl : existing.faceUrl,
          latestMsg: useExisting ? existing.latestMsg : conv.latestMsg,
          latestMsgSendTime: useExisting
              ? existing.latestMsgSendTime
              : conv.latestMsgSendTime,
          unreadCount: conv.unreadCount,
          recvMsgOpt: conv.recvMsgOpt,
          isPinned: conv.isPinned,
          isPrivateChat: conv.isPrivateChat,
          burnDuration: conv.burnDuration,
          groupAtType: conv.groupAtType,
          isNotInGroup: conv.isNotInGroup,
          updateUnreadCountTime: conv.updateUnreadCountTime,
          attachedInfo: conv.attachedInfo,
          ex: conv.ex,
          draftText: existing.draftText.isNotEmpty
              ? existing.draftText
              : conv.draftText,
          draftTextTime: existing.draftTextTime > 0
              ? existing.draftTextTime
              : conv.draftTextTime,
          maxSeq: conv.maxSeq,
          minSeq: conv.minSeq,
          isMsgDestruct: conv.isMsgDestruct,
          msgDestructTime: conv.msgDestructTime,
        );
      } else {
        newConversations.add(conv);
      }
    }
    newConversations.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.latestMsgSendTime.toInt().compareTo(a.latestMsgSendTime.toInt());
    });
    state = state.copyWith(conversations: newConversations);
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
    final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    final exists = list.any((m) => m.clientMsgId == message.clientMsgId);
    if (!exists) {
      list.add(message);
    }
    newMessages[conversationId] = List<MessageInfo>.from(list);
    state = state.copyWith(messages: newMessages);
  }

  void _onUserEvent(UserEvent event) {
    event.when(
      userInfoUpdated: (user) {
        appLog.i('[MsgSvc] userInfoUpdated: ${user.userId}');
        if (user.userId == state.currentUserId) {
          unawaited(refreshLoginUserProfile());
        }
      },
      userStatusChanged: (userId, status, platformIds) {
        appLog.i(
          '[MsgSvc] userStatusChanged: userId=$userId status=$status platformIds=$platformIds',
        );
        OnlineStatusService.instance.applyUserStatusChanged(
          userId: userId,
          status: status,
          platformIds: platformIds,
        );
      },
    );
  }

  bool _loadingConversations = false;
  bool _reloadConversationsPending = false;

  Future<void> _loadConversations() async {
    if (_client == null) {
      appLog.w('[MessageService] _loadConversations 跳过：client 为空');
      return;
    }
    // 防止并发调用导致状态乱序：正在加载时记一次待重载，完成后补一次
    if (_loadingConversations) {
      _reloadConversationsPending = true;
      return;
    }
    _loadingConversations = true;

    try {
      final conversations = await _repository.getConversations();
      final newConversations = List<LocalConversation>.from(
        state.conversations,
      );
      final dbIds = conversations.map((c) => c.conversationId).toSet();
      newConversations.removeWhere((c) => !dbIds.contains(c.conversationId));
      // 去重：移除 DB 中重复的同 ID 行（兜底 DB 无 UNIQUE 约束的情况）
      final seenIds = <String>{};
      newConversations.removeWhere((c) => !seenIds.add(c.conversationId));
      for (final conv in conversations) {
        final index = newConversations.indexWhere(
          (c) => c.conversationId == conv.conversationId,
        );
        if (index >= 0) {
          final existing = newConversations[index];
          final existingTime = existing.latestMsgSendTime.toInt();
          final convTime = conv.latestMsgSendTime.toInt();
          final useExisting =
              existing.latestMsg.isNotEmpty && existingTime >= convTime;
          newConversations[index] = LocalConversation(
            conversationId: conv.conversationId,
            conversationType: conv.conversationType,
            userId: conv.userId,
            groupId: conv.groupId,
            showName: conv.showName.isNotEmpty
                ? conv.showName
                : existing.showName,
            faceUrl: conv.faceUrl.isNotEmpty ? conv.faceUrl : existing.faceUrl,
            latestMsg: useExisting ? existing.latestMsg : conv.latestMsg,
            latestMsgSendTime: useExisting
                ? existing.latestMsgSendTime
                : conv.latestMsgSendTime,
            unreadCount: conv.unreadCount,
            recvMsgOpt: conv.recvMsgOpt,
            isPinned: conv.isPinned,
            isPrivateChat: conv.isPrivateChat,
            burnDuration: conv.burnDuration,
            groupAtType: conv.groupAtType,
            isNotInGroup: conv.isNotInGroup,
            updateUnreadCountTime: conv.updateUnreadCountTime,
            attachedInfo: conv.attachedInfo,
            ex: conv.ex,
            draftText: existing.draftText.isNotEmpty
                ? existing.draftText
                : conv.draftText,
            draftTextTime: existing.draftTextTime > 0
                ? existing.draftTextTime
                : conv.draftTextTime,
            maxSeq: conv.maxSeq,
            minSeq: conv.minSeq,
            isMsgDestruct: conv.isMsgDestruct,
            msgDestructTime: conv.msgDestructTime,
          );
        } else {
          newConversations.add(conv);
        }
      }
      newConversations.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aTime = a.latestMsgSendTime.toInt();
        final bTime = b.latestMsgSendTime.toInt();
        return bTime.compareTo(aTime);
      });
      state = state.copyWith(conversations: newConversations);
      final userIds = conversations
          .where((c) => c.userId.isNotEmpty)
          .map((c) => c.userId)
          .toSet()
          .toList();
      unawaited(preloadUserProfiles(userIds));
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载会话列表失败: $e');
    } finally {
      _loadingConversations = false;
      if (_reloadConversationsPending) {
        _reloadConversationsPending = false;
        unawaited(_loadConversations());
      }
    }
  }

  Future<void> refreshConversations() async {
    await _loadConversations();
  }

  void removeConversation(String conversationId) {
    final newConversations = List<LocalConversation>.from(state.conversations);
    newConversations.removeWhere((c) => c.conversationId == conversationId);
    final newMessages = Map<String, List<MessageInfo>>.from(state.messages);
    newMessages.remove(conversationId);
    state = state.copyWith(
      conversations: newConversations,
      messages: newMessages,
    );
  }

  Future<void> disconnect() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _client?.disconnect();
    _client = null;
    OnlineStatusService.instance.setClient(null);
    state = const MessageServiceState();
  }

  /// 标记会话为已读
  Future<void> markConversationMessageAsRead(String conversationId) async {
    if (_client == null) return;
    try {
      // 从本地状态查找会话类型
      final conv = state.conversations
          .where((c) => c.conversationId == conversationId)
          .firstOrNull;
      final sessionType = conv?.sessionType ?? SessionType.singleChat;
      appLog.i('[READ] Service 标记已读: sessionType=$sessionType');
      await _repository.markConversationMessageAsRead(
        conversationId: conversationId,
        sessionType: sessionType,
      );
      // 更新本地会话未读数
      final newConversations = List<LocalConversation>.from(
        state.conversations,
      );
      final idx = newConversations.indexWhere(
        (c) => c.conversationId == conversationId,
      );
      if (idx >= 0) {
        final conv = newConversations[idx];
        newConversations[idx] = LocalConversation(
          conversationId: conv.conversationId,
          conversationType: conv.conversationType,
          userId: conv.userId,
          groupId: conv.groupId,
          showName: conv.showName,
          faceUrl: conv.faceUrl,
          latestMsg: conv.latestMsg,
          latestMsgSendTime: conv.latestMsgSendTime,
          unreadCount: 0,
          recvMsgOpt: conv.recvMsgOpt,
          isPinned: conv.isPinned,
          isPrivateChat: conv.isPrivateChat,
          burnDuration: conv.burnDuration,
          groupAtType: conv.groupAtType,
          isNotInGroup: conv.isNotInGroup,
          updateUnreadCountTime: conv.updateUnreadCountTime,
          attachedInfo: conv.attachedInfo,
          ex: conv.ex,
          draftText: conv.draftText,
          draftTextTime: conv.draftTextTime,
          maxSeq: conv.maxSeq,
          minSeq: conv.minSeq,
          isMsgDestruct: conv.isMsgDestruct,
          msgDestructTime: conv.msgDestructTime,
        );
      }
      state = state.copyWith(conversations: newConversations);

      // 注意：不再调用 _refreshMessagesAfterRead
      // 标记已读后，消息的 isRead 状态会在下次加载消息时从数据库同步
      // 避免重复查询数据库造成性能浪费
    } catch (e) {
      appLog.e('[READ] 标记已读失败: $e');
    }
  }

  /// 保存草稿
  Future<void> saveDraft(String conversationId, String draftText) async {
    if (_client == null) return;
    try {
      // 先同步更新内存状态，确保会话列表立即显示草稿
      final newConversations = List<LocalConversation>.from(
        state.conversations,
      );
      final idx = newConversations.indexWhere(
        (c) => c.conversationId == conversationId,
      );
      if (idx >= 0) {
        final conv = newConversations[idx];
        final now = DateTime.now().millisecondsSinceEpoch;
        newConversations[idx] = LocalConversation(
          conversationId: conv.conversationId,
          conversationType: conv.conversationType,
          userId: conv.userId,
          groupId: conv.groupId,
          showName: conv.showName,
          faceUrl: conv.faceUrl,
          latestMsg: conv.latestMsg,
          latestMsgSendTime: conv.latestMsgSendTime,
          unreadCount: conv.unreadCount,
          recvMsgOpt: conv.recvMsgOpt,
          isPinned: conv.isPinned,
          isPrivateChat: conv.isPrivateChat,
          burnDuration: conv.burnDuration,
          groupAtType: conv.groupAtType,
          isNotInGroup: conv.isNotInGroup,
          updateUnreadCountTime: conv.updateUnreadCountTime,
          attachedInfo: conv.attachedInfo,
          ex: conv.ex,
          draftText: draftText,
          draftTextTime: now,
          maxSeq: conv.maxSeq,
          minSeq: conv.minSeq,
          isMsgDestruct: conv.isMsgDestruct,
          msgDestructTime: conv.msgDestructTime,
        );
        state = state.copyWith(conversations: newConversations);
      }

      // 异步保存到数据库
      await _repository.setConversationDraft(
        conversationId: conversationId,
        draftText: draftText,
      );
    } catch (e) {
      appLog.e('[MessageService] 保存草稿失败: $e');
    }
  }

  /// 清除草稿
  Future<void> clearDraft(String conversationId) async {
    if (_client == null) return;
    try {
      // 先同步更新内存状态
      final newConversations = List<LocalConversation>.from(
        state.conversations,
      );
      final idx = newConversations.indexWhere(
        (c) => c.conversationId == conversationId,
      );
      if (idx >= 0) {
        final conv = newConversations[idx];
        newConversations[idx] = LocalConversation(
          conversationId: conv.conversationId,
          conversationType: conv.conversationType,
          userId: conv.userId,
          groupId: conv.groupId,
          showName: conv.showName,
          faceUrl: conv.faceUrl,
          latestMsg: conv.latestMsg,
          latestMsgSendTime: conv.latestMsgSendTime,
          unreadCount: conv.unreadCount,
          recvMsgOpt: conv.recvMsgOpt,
          isPinned: conv.isPinned,
          isPrivateChat: conv.isPrivateChat,
          burnDuration: conv.burnDuration,
          groupAtType: conv.groupAtType,
          isNotInGroup: conv.isNotInGroup,
          updateUnreadCountTime: conv.updateUnreadCountTime,
          attachedInfo: conv.attachedInfo,
          ex: conv.ex,
          draftText: '',
          draftTextTime: 0,
          maxSeq: conv.maxSeq,
          minSeq: conv.minSeq,
          isMsgDestruct: conv.isMsgDestruct,
          msgDestructTime: conv.msgDestructTime,
        );
        state = state.copyWith(conversations: newConversations);
      }

      // 异步清除数据库中的草稿
      await _repository.clearConversationDraft(conversationId: conversationId);
    } catch (e) {
      appLog.e('[MessageService] 清除草稿失败: $e');
    }
  }

  /// 切换会话置顶
  Future<void> toggleConversationPin(
    String conversationId,
    bool isPinned,
  ) async {
    if (_client == null) return;
    try {
      await _repository.setConversationPinned(
        conversationId: conversationId,
        isPinned: isPinned,
      );
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 切换置顶失败: $e');
    }
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    if (_client == null) return;
    try {
      await _repository.deleteConversation(conversationId: conversationId);
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 删除会话失败: $e');
    }
  }

  /// 隐藏会话
  Future<void> hideConversation(String conversationId) async {
    if (_client == null) return;
    try {
      await _repository.hideConversation(conversationId: conversationId);
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 隐藏会话失败: $e');
    }
  }

  /// 标记所有会话为已读
  Future<void> markAllConversationsAsRead() async {
    if (_client == null) return;
    try {
      await _repository.markAllConversationsAsRead();
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 标记全部已读失败: $e');
    }
  }
}
