import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/extensions/conversation_extensions.dart';
import 'package:flutter_rust_demo/models/message_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart' as fb;
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart' show Message;
import 'package:flutter_rust_demo/src/rust/domain/config.dart';
import 'package:flutter_rust_demo/src/rust/domain/constant/enums.dart';
import 'package:flutter_rust_demo/src/rust/sdk/client/types.dart';
import 'package:flutter_rust_demo/src/rust/domain/model/user.dart' show UserInfo;
import 'package:flutter_rust_demo/src/rust/infra/database/models.dart' show LocalConversation;
import 'package:flutter_rust_demo/src/rust/api/simple.dart' show initLogger;
import 'package:flutter_rust_demo/src/rust/domain/model/message.dart' show MessageInfo;
import 'package:flutter_rust_demo/src/rust/domain/listener/connection.dart';
import 'package:flutter_rust_demo/src/rust/domain/listener/conversation.dart';
import 'package:flutter_rust_demo/src/rust/domain/listener/friend.dart';
import 'package:flutter_rust_demo/src/rust/domain/listener/group.dart';
import 'package:flutter_rust_demo/utils/app_logger.dart';
import 'package:flutter_rust_demo/utils/login_storage.dart';
import 'package:flutter_rust_demo/services/navigation_service.dart';

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
  }) {
    return MessageServiceState(
      isConnected: isConnected ?? this.isConnected,
      isSyncingConversations: isSyncingConversations ?? this.isSyncingConversations,
      syncProgress: syncProgress ?? this.syncProgress,
      currentUserId: currentUserId ?? this.currentUserId,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      userProfiles: userProfiles ?? this.userProfiles,
      loginUserProfile: loginUserProfile ?? this.loginUserProfile,
      isInitializing: isInitializing ?? this.isInitializing,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }
}

/// MessageService 的 StateNotifier
class MessageServiceNotifier extends StateNotifier<MessageServiceState> {
  final Ref _ref;
  fb.OpenImBridgeClient? _client;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  /// 已处理的 clientMsgId 集合，防止同一消息被重复添加到列表
  final Set<String> _seenClientMsgIds = {};

  MessageServiceNotifier(this._ref) : super(const MessageServiceState());

  /// 获取客户端实例
  fb.OpenImBridgeClient? get client => _client;

  /// 将 sendTime 规范化为毫秒（自动检测秒/毫秒）
  static int _normalizeSendTime(int t) {
    if (t <= 0) return DateTime.now().millisecondsSinceEpoch;
    // 如果小于 2000-01-01 的毫秒时间戳，认为是秒级
    if (t < 946684800000) return t * 1000;
    return t;
  }

  /// 获取指定会话的消息列表
  List<MessageInfo> getMessages(String conversationId) {
    return List.unmodifiable(this.state.messages[conversationId] ?? []);
  }

  /// 将发送结果写入全局消息状态（替代已移除的 messageSent 事件）
  void upsertSentMessage(String conversationId, Message result) {
    final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
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
      createTime: result.createTime > 0 ? result.createTime : _normalizeSendTime(result.sendTime.toInt()),
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
    this.state = this.state.copyWith(messages: newMessages);
  }

  /// 获取指定用户资料（命中缓存时）
  UserInfo? getUserProfile(String userId) => this.state.userProfiles[userId];

  /// 拉取当前登录用户资料（通过批量接口 getUsersInfo，走缓存）并更新内存缓存
  Future<UserInfo?> refreshLoginUserProfile() async {
    if (_client == null || this.state.currentUserId.isEmpty) return null;
    try {
      final list = await _client!.getUsersInfo(userIds: [this.state.currentUserId]);
      final profile = list.isNotEmpty ? list.first : null;
      if (profile != null) {
        final newUserProfiles = Map<String, UserInfo>.from(this.state.userProfiles);
        newUserProfiles[profile.userId] = profile;
        this.state = this.state.copyWith(
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
      final list = await _client!.getUsersInfo(userIds: uniq);
      final newUserProfiles = Map<String, UserInfo>.from(this.state.userProfiles);
      for (final p in list) {
        newUserProfiles[p.userId] = p;
      }
      this.state = this.state.copyWith(userProfiles: newUserProfiles);
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
      await _client!.updateUserProfile(
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
      appLog.i('[MSG] Service 加载历史消息: count=$count');
      final result = await _client!.getHistoryMessages(
        req: GetHistoryMessagesReq(
          conversationId: conversationId,
          startClientMsgId: startClientMsgId,
          count: count,
        ),
      );

      appLog.i('[MSG] Service 加载完成: messages=${result.messages.length}, isEnd=${result.isEnd}');

      if (result.messages.isEmpty) {
        return false;
      }

      final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
      final currentMessages = newMessages.putIfAbsent(conversationId, () => []);

      // result.messages 已经是 List<MessageInfo>，直接使用
      currentMessages.insertAll(0, result.messages);

      final seenIds = <String>{};
      newMessages[conversationId] = currentMessages
          .where((msg) => seenIds.add(msg.clientMsgId))
          .toList();

      this.state = this.state.copyWith(messages: newMessages);

      return !result.isEnd;
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载历史消息失败: $e');
      return false;
    }
  }

  /// 标记已读后刷新消息列表（从数据库重新加载，确保 isRead 状态同步）
  /// 对齐 Go SDK：Go 侧 MarkConversationMessageAsReadDB 更新 DB 后，
  /// Flutter 侧需重新加载消息以获取最新 is_read 状态
  Future<void> _refreshMessagesAfterRead(String conversationId) async {
    if (_client == null) return;
    try {
      final result = await _client!.getHistoryMessages(
        req: GetHistoryMessagesReq(
          conversationId: conversationId,
          startClientMsgId: '',
          count: 20,
        ),
      );
      if (result.messages.isNotEmpty) {
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        newMessages[conversationId] = result.messages;
        this.state = this.state.copyWith(messages: newMessages);
        appLog.i('[READ] _refreshMessagesAfterRead: conv=$conversationId msgs=${result.messages.length}');
      }
    } catch (e) {
      appLog.e('[READ] _refreshMessagesAfterRead FAILED: $e');
    }
  }

  Future<Message> sendTextMessage({
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
    return _client!.sendTextMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送 Markdown 消息
  Future<Message> sendMarkdownMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return _client!.sendMarkdownMessage(
      text: text,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 转发消息（按 clientMsgId 原样转发，对齐 Go SDK ForwardMessage）
  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await fb.forwardMessageByClientId(
      clientMsgId: clientMsgId,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送图片消息
  Future<Message> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return _client!.sendImageMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送视频消息
  Future<Message> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return _client!.sendVideoMessage(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  /// 发送语音消息
  Future<Message> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return _client!.sendSoundMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  /// 发送文件消息
  Future<Message> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return _client!.sendFileMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送位置消息
  Future<Message> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return fb.sendLocationMessage(
      description: description,
      latitude: latitude,
      longitude: longitude,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送表情消息
  Future<Message> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return fb.sendFaceMessage(
      index: index,
      data: data,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送名片消息
  Future<Message> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return fb.sendCardMessage(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送引用消息
  Future<Message> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    return fb.sendQuoteMessage(
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
    await _client!.revokeMessage(
      req: RevokeMessageReq(
        conversationId: conversationId,
        seq: seq,
        clientMsgId: clientMsgId,
        sessionType: sessionType,
      ),
    );
  }

  /// 删除消息（本地+服务端）
  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await fb.deleteMessage(
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
    if (_client != null && this.state.isConnected) {
      appLog.i('ℹ️ 客户端已连接，跳过重复初始化（热更新场景）');
      return;
    }

    if (this.state.isInitializing) {
      appLog.w('⚠️ 初始化正在进行中，跳过重复调用');
      return;
    }

    this.state = this.state.copyWith(isInitializing: true);
    appLog.i('[MessageService] initialize 开始');
    try {
      // 关闭已有客户端（热重启或重复登录场景），避免两个实例同时存在导致被踢
      if (_client != null) {
        appLog.i('[MessageService] 关闭已有客户端，重新初始化');
        for (final s in _subscriptions) { await s.cancel(); }
        _subscriptions.clear();
        try {
          await _client!.disconnect();
        } catch (e) {
          appLog.w('[MessageService] 关闭旧客户端失败: $e');
        }
        _client = null;
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

      this.state = this.state.copyWith(currentUserId: resolvedUserId);

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
      unawaited(_loadConversations());

      _subscriptions.add(_client!.connectionStream().listen(_onConnectionEvent));
      _subscriptions.add(_client!.conversationStream().listen(_onConversationEvent));
      _subscriptions.add(_client!.friendStream().listen(_onFriendEvent));
      _subscriptions.add(_client!.groupStream().listen(_onGroupEvent));
      appLog.i('[MessageService] 4 模块事件流已注册');

      this.state = this.state.copyWith(isConnected: true);
      appLog.i('✅ 客户端连接成功');

      // 用户资料后台加载，不阻塞进入主页
      unawaited(refreshLoginUserProfile());

      // 再次从 DB 加载会话，确保最新
      _loadConversations();
    } catch (e) {
      appLog.e('❌ 初始化失败: $e');
      this.state = this.state.copyWith(isConnected: false);
      rethrow;
    } finally {
      this.state = this.state.copyWith(isInitializing: false);
    }
  }

  void _updateConversation(LocalConversation conv) {
    final newConversations = List<LocalConversation>.from(this.state.conversations);
    final index = newConversations.indexWhere(
      (c) => c.conversationId == conv.conversationId,
    );

    final isUpdate = index >= 0;
    if (isUpdate) {
      final existing = newConversations[index];
      // 保留本地维护的字段（草稿、最新消息），避免 DB 查询与消息更新间的竞态导致被旧值覆盖
      final draftText = existing.draftText.isNotEmpty ? existing.draftText : conv.draftText;
      final draftTextTime = draftText.isNotEmpty
          ? (existing.draftTextTime > 0 ? existing.draftTextTime : conv.draftTextTime)
          : conv.draftTextTime;
      // 保留较新的 latestMsg（内存中的可能比 DB 查询到的更新）
      final existingTime = existing.latestMsgSendTime.toInt();
      final convTime = conv.latestMsgSendTime.toInt();
      final useExisting = existing.latestMsg.isNotEmpty && existingTime >= convTime;
      newConversations[index] = LocalConversation(
        conversationId: conv.conversationId,
        conversationType: conv.conversationType,
        userId: conv.userId,
        groupId: conv.groupId,
        showName: conv.showName,
        faceUrl: conv.faceUrl,
        latestMsg: useExisting ? existing.latestMsg : conv.latestMsg,
        latestMsgSendTime: useExisting ? existing.latestMsgSendTime : conv.latestMsgSendTime,
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
        draftTextTime: draftTextTime,
        maxSeq: conv.maxSeq,
        minSeq: conv.minSeq,
        isMsgDestruct: conv.isMsgDestruct,
        msgDestructTime: conv.msgDestructTime,
      );
    } else {
      newConversations.add(conv);
    }

    newConversations.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned == 1 ? -1 : 1;
      }
      final aTime = a.latestMsgSendTime.toInt();
      final bTime = b.latestMsgSendTime.toInt();
      return bTime.compareTo(aTime);
    });

    this.state = this.state.copyWith(conversations: newConversations);
  }

  void _onConnectionEvent(ConnectionEvent event) {
    appLog.i('[MsgSvc] _onConnectionEvent: ${event.runtimeType}');
    event.maybeWhen(
      connected: () {
        appLog.i('[MsgSvc] connected!');
        this.state = this.state.copyWith(isConnected: true);
        _loadConversations();
      },
      kickedOffline: (_) => this.state = this.state.copyWith(isConnected: false),
      tokenExpired: () {
        this.state = this.state.copyWith(isConnected: false);
        LoginStorage.clearCredentials().catchError((_) {});
        NavigationService.instance.goToLogin();
      },
      orElse: () {},
    );
  }

  void _onConversationEvent(ConversationEvent event) {
    event.maybeWhen(
      syncStarted: () => this.state = this.state.copyWith(isSyncingConversations: true, syncProgress: 0),
      syncFinished: () { this.state = this.state.copyWith(isSyncingConversations: false, syncProgress: 100); _loadConversations(); },
      syncProgress: (p, _) => this.state = this.state.copyWith(isSyncingConversations: true, syncProgress: p),
      totalUnreadCountChanged: (c) {
        appLog.i('[MsgSvc] totalUnreadCountChanged: $c');
        this.state = this.state.copyWith(totalUnreadCount: c);
      },
      changed: (_) { appLog.i('[MsgSvc] conversationChanged'); _loadConversations(); },
      new_: (_) { appLog.i('[MsgSvc] newConversation'); _loadConversations(); },
      deleted: (_) => appLog.i('[MsgSvc] conversationDeleted'),
      userInputStatusChanged: (cid, uid, _) => appLog.i('[MsgSvc] typing: conv=$cid user=$uid'),
      syncFailed: (e) => appLog.i('[MsgSvc] syncFailed: $e'),
      orElse: () {},
    );
  }

  void _onFriendEvent(FriendEvent event) {}
  void _onGroupEvent(GroupEvent event) {}


  bool _loadingConversations = false;

  Future<void> _loadConversations() async {
    if (_client == null) {
      appLog.w('[MessageService] _loadConversations 跳过：client 为空');
      return;
    }
    // 防止并发调用导致状态乱序
    if (_loadingConversations) return;
    _loadingConversations = true;

    try {
      final conversations = await _client!.getConversations();
      final newConversations = List<LocalConversation>.from(this.state.conversations);
      final dbIds = conversations.map((c) => c.conversationId).toSet();
      newConversations.removeWhere((c) => !dbIds.contains(c.conversationId));
      // 去重：移除 DB 中重复的同 ID 行（兜底 DB 无 UNIQUE 约束的情况）
      final seenIds = <String>{};
      newConversations.removeWhere((c) => !seenIds.add(c.conversationId));
      for (final conv in conversations) {
        final index = newConversations.indexWhere((c) => c.conversationId == conv.conversationId);
        if (index >= 0) {
          final existing = newConversations[index];
          final existingTime = existing.latestMsgSendTime.toInt();
          final convTime = conv.latestMsgSendTime.toInt();
          final useExisting = existing.latestMsg.isNotEmpty && existingTime >= convTime;
          newConversations[index] = LocalConversation(
            conversationId: conv.conversationId,
            conversationType: conv.conversationType,
            userId: conv.userId,
            groupId: conv.groupId,
            showName: conv.showName.isNotEmpty ? conv.showName : existing.showName,
            faceUrl: conv.faceUrl.isNotEmpty ? conv.faceUrl : existing.faceUrl,
            latestMsg: useExisting ? existing.latestMsg : conv.latestMsg,
            latestMsgSendTime: useExisting ? existing.latestMsgSendTime : conv.latestMsgSendTime,
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
            draftText: existing.draftText.isNotEmpty ? existing.draftText : conv.draftText,
            draftTextTime: existing.draftTextTime > 0 ? existing.draftTextTime : conv.draftTextTime,
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
        if (a.isPinned != b.isPinned) return a.isPinned == 1 ? -1 : 1;
        final aTime = a.latestMsgSendTime.toInt();
        final bTime = b.latestMsgSendTime.toInt();
        return bTime.compareTo(aTime);
      });
      this.state = this.state.copyWith(conversations: newConversations);
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
    }
  }

  Future<void> refreshConversations() async {
    await _loadConversations();
  }

  void removeConversation(String conversationId) {
    final newConversations = List<LocalConversation>.from(this.state.conversations);
    newConversations.removeWhere((c) => c.conversationId == conversationId);
    final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
    newMessages.remove(conversationId);
    this.state = this.state.copyWith(
      conversations: newConversations,
      messages: newMessages,
    );
  }

  Future<void> disconnect() async {
    for (final s in _subscriptions) { await s.cancel(); }
    _subscriptions.clear();
    await _client?.disconnect();
    _client = null;
    this.state = const MessageServiceState();
  }

  /// 标记会话为已读
  Future<void> markConversationMessageAsRead(String conversationId) async {
    if (_client == null) return;
    try {
      // 从本地状态查找会话类型
      final conv = this.state.conversations.where((c) => c.conversationId == conversationId).firstOrNull;
      final sessionType = conv?.sessionType ?? SessionType.singleChat;
      appLog.i('[READ] Service 标记已读: sessionType=$sessionType');
      await _client!.markConversationMessageAsRead(conversationId: conversationId, sessionType: sessionType);
      // 更新本地会话未读数
      final newConversations = List<LocalConversation>.from(this.state.conversations);
      final idx = newConversations.indexWhere((c) => c.conversationId == conversationId);
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
      this.state = this.state.copyWith(conversations: newConversations);

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
      final newConversations = List<LocalConversation>.from(this.state.conversations);
      final idx = newConversations.indexWhere((c) => c.conversationId == conversationId);
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
        this.state = this.state.copyWith(conversations: newConversations);
      }
      
      // 异步保存到数据库
      await _client!.setConversationDraft(conversationId: conversationId, draftText: draftText);
    } catch (e) {
      appLog.e('[MessageService] 保存草稿失败: $e');
    }
  }

  /// 清除草稿
  Future<void> clearDraft(String conversationId) async {
    if (_client == null) return;
    try {
      // 先同步更新内存状态
      final newConversations = List<LocalConversation>.from(this.state.conversations);
      final idx = newConversations.indexWhere((c) => c.conversationId == conversationId);
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
        this.state = this.state.copyWith(conversations: newConversations);
      }
      
      // 异步清除数据库中的草稿
      await _client!.clearConversationDraft(conversationId: conversationId);
    } catch (e) {
      appLog.e('[MessageService] 清除草稿失败: $e');
    }
  }

  /// 切换会话置顶
  Future<void> toggleConversationPin(String conversationId, bool isPinned) async {
    if (_client == null) return;
    try {
      await _client!.setConversationPinned(conversationId: conversationId, isPinned: isPinned);
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 切换置顶失败: $e');
    }
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    if (_client == null) return;
    try {
      await _client!.deleteConversation(conversationId: conversationId);
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 删除会话失败: $e');
    }
  }

  /// 标记所有会话为已读
  Future<void> markAllConversationsAsRead() async {
    if (_client == null) return;
    try {
      await fb.markAllConversationMessageAsRead();
      _loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 标记全部已读失败: $e');
    }
  }
}
