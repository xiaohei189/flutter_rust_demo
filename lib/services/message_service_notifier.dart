import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/extensions/conversation_extensions.dart';
import 'package:flutter_rust_demo/models/message_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart' as fb;
import 'package:flutter_rust_demo/src/rust/domain/config.dart';
import 'package:flutter_rust_demo/src/rust/domain/constant/enums.dart';
import 'package:flutter_rust_demo/src/rust/sdk/client/types.dart';
import 'package:flutter_rust_demo/src/rust/domain/model/user.dart' show UserInfo;
import 'package:flutter_rust_demo/src/rust/infra/database/models.dart' show LocalConversation;
import 'package:flutter_rust_demo/src/rust/api/simple.dart' show initLogger;
import 'package:flutter_rust_demo/src/rust/domain/model/message.dart' show MessageInfo;
import 'package:flutter_rust_demo/src/rust/domain/event/types.dart' show SdkEvent;
import 'package:flutter_rust_demo/utils/app_logger.dart';
import 'package:flutter_rust_demo/utils/login_storage.dart';

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
    );
  }
}

/// MessageService 的 StateNotifier
class MessageServiceNotifier extends StateNotifier<MessageServiceState> {
  final Ref _ref;
  fb.OpenImBridgeClient? _client;
  StreamSubscription<dynamic>? _eventStreamSubscription;

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

  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (_client == null) {
      throw StateError('客户端未初始化');
    }
    if (recvId.trim().isEmpty && groupId.trim().isEmpty) {
      throw ArgumentError('recvId 与 groupId 至少填一个');
    }

    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    await _client!.sendTextMessage(
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
  Future<void> sendImageMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await _client!.sendImageMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送视频消息
  Future<void> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await _client!.sendVideoMessage(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  /// 发送语音消息
  Future<void> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
    required int duration,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await _client!.sendSoundMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
      duration: duration,
    );
  }

  /// 发送文件消息
  Future<void> sendFileMessage({
    required String filePath,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await _client!.sendFileMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送位置消息
  Future<void> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await fb.sendLocationMessage(
      description: description,
      latitude: latitude,
      longitude: longitude,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送表情消息
  Future<void> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await fb.sendFaceMessage(
      index: index,
      data: data,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送名片消息
  Future<void> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await fb.sendCardMessage(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 发送引用消息
  Future<void> sendQuoteMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  }) async {
    if (_client == null) throw StateError('客户端未初始化');
    await fb.sendQuoteMessage(
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
      appLog.i('[MessageService] 即将调用 initLogger');
      await initLogger(logLevel: 'info,rust_lib_flutter_rust_demo=debug');
      appLog.i('[MessageService] initLogger 完成');

      final String resolvedUserId;
      final String resolvedImToken;
      if (userId != null &&
          userId.isNotEmpty &&
          imToken != null &&
          imToken.isNotEmpty) {
        resolvedUserId = userId;
        resolvedImToken = imToken;
        appLog.i('✅ 使用传入凭证连接，用户ID: $resolvedUserId');
      } else {
        throw StateError('缺少 userId 或 imToken，请先登录');
      }

      this.state = this.state.copyWith(currentUserId: resolvedUserId);

      appLog.i('[MessageService] 即将调用 OpenImBridgeClient.newInstance');
      final docDir = await getApplicationDocumentsDirectory();
      final dataDir = '${docDir.path}/openim_data';
      appLog.i('[MessageService] 数据目录: $dataDir');
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
      appLog.i('[MessageService] newInstance 完成');

      appLog.i('[MessageService] 立即加载本地缓存的会话列表');
      unawaited(_loadConversations());

      _eventStreamSubscription = _client!.eventStream().listen(
        _handleEvent,
      );
      appLog.i('[MessageService] 流订阅已注册');

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
      // 如果已有草稿文本，保留已有的（服务端/DB 不会推送草稿字段，可能为空）
      final draftText = existing.draftText.isNotEmpty ? existing.draftText : conv.draftText;
      final draftTextTime = draftText.isNotEmpty
          ? (existing.draftTextTime > 0 ? existing.draftTextTime : conv.draftTextTime)
          : conv.draftTextTime;
      newConversations[index] = LocalConversation(
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

  /// 处理统一事件（连接、会话、消息）
  void _handleEvent(SdkEvent event) {
    event.maybeWhen(
      connecting: () {
        appLog.i('[MessageService] 正在连接...');
      },
      connected: () {
        this.state = this.state.copyWith(isConnected: true);
        appLog.i('[MessageService] 连接成功，主动拉取一次会话列表');
        _loadConversations();
      },
      connectFailed: (error) {
        this.state = this.state.copyWith(isConnected: false);
      },
      disconnected: (reason) {
        appLog.i('[MessageService] 连接断开: $reason');
        this.state = this.state.copyWith(isConnected: false);
      },
      kickedOffline: (reason) {
        this.state = this.state.copyWith(isConnected: false);
      },
      tokenExpired: () {
        this.state = this.state.copyWith(isConnected: false);
      },
      syncStarted: () {
        this.state = this.state.copyWith(isSyncingConversations: true, syncProgress: 0);
      },
      syncFinished: () {
        this.state = this.state.copyWith(isSyncingConversations: false, syncProgress: 100);
        _loadConversations();
      },
      syncProgress: (progress, message) {
        this.state = this.state.copyWith(isSyncingConversations: true, syncProgress: progress);
      },
      syncFailed: (error) {
        this.state = this.state.copyWith(isSyncingConversations: false);
      },
      newConversation: (conversations) {
        _loadConversations();
      },
      conversationChanged: (conversations) {
        appLog.i('[ConvEvent] conversationChanged 收到 ${conversations.length} 条');
        for (final conv in conversations) {
          // 查找内存中已有的会话，保留本地维护的字段（latestMsg 等）
          // 服务端同步不返回这些字段，但 Rust DAO 的 upsert_preserving_local_fields
          // 已在数据库层保留；这里需要在内存层也做同样保留，避免被空值覆盖
          final existing = state.conversations.cast<LocalConversation?>().firstWhere(
            (c) => c?.conversationId == conv.conversationId,
            orElse: () => null,
          );
          appLog.i(
            '[ConvEvent] ${conv.conversationId} | '
            '事件数据: showName="${conv.showName}" faceUrl="${conv.faceUrl}" '
            'latestMsg="${conv.latestMsg.length > 40 ? conv.latestMsg.substring(0, 40) : conv.latestMsg}" '
            'latestMsgSendTime=${conv.latestMsgSendTime} unread=${conv.unreadCount} '
            'pinned=${conv.isPinned} recvMsgOpt=${conv.recvMsgOpt}',
          );
          if (existing != null) {
            appLog.i(
              '[ConvEvent] ${conv.conversationId} | '
              '内存已有: showName="${existing.showName}" faceUrl="${existing.faceUrl}" '
              'latestMsg="${existing.latestMsg.length > 40 ? existing.latestMsg.substring(0, 40) : existing.latestMsg}" '
              'latestMsgSendTime=${existing.latestMsgSendTime} unread=${existing.unreadCount}',
            );
          } else {
            appLog.i('[ConvEvent] ${conv.conversationId} | 内存中无此会话（首次）');
          }
          _updateConversation(LocalConversation(
            conversationId: conv.conversationId,
            conversationType: conv.conversationType,
            userId: conv.userId,
            groupId: conv.groupId,
            showName: conv.showName.isNotEmpty ? conv.showName : (existing?.showName ?? ''),
            faceUrl: conv.faceUrl.isNotEmpty ? conv.faceUrl : (existing?.faceUrl ?? ''),
            latestMsg: conv.latestMsg.isNotEmpty ? conv.latestMsg : (existing?.latestMsg ?? ''),
            latestMsgSendTime: conv.latestMsgSendTime > 0 ? conv.latestMsgSendTime : (existing?.latestMsgSendTime ?? 0),
            unreadCount: conv.unreadCount >= 0 ? conv.unreadCount : (existing?.unreadCount ?? 0),
            recvMsgOpt: conv.recvMsgOpt,
            isPinned: conv.isPinned ? 1 : 0,
            isNotInGroup: existing?.isNotInGroup ?? 0,
            draftText: conv.draftText.isNotEmpty ? conv.draftText : (existing?.draftText ?? ''),
            draftTextTime: conv.draftTextTime > 0 ? conv.draftTextTime : (existing?.draftTextTime ?? 0),
            isPrivateChat: conv.isPrivateChat ? 1 : 0,
            burnDuration: conv.burnDuration > 0 ? conv.burnDuration : (existing?.burnDuration ?? 0),
            groupAtType: conv.groupAtType,
            updateUnreadCountTime: conv.updateUnreadCountTime,
            maxSeq: conv.maxSeq,
            minSeq: conv.minSeq,
            isMsgDestruct: conv.isMsgDestruct ? 1 : 0,
            msgDestructTime: conv.msgDestructTime,
            attachedInfo: existing?.attachedInfo ?? '',
            ex: existing?.ex ?? '',
          ));
        }
      },
      conversationDeleted: (conversationIds) {
        _loadConversations();
      },
      newMessage: (message) {
        _loadConversations();
        final convId = message.conversationId;
        if (convId.isEmpty) return;
        final msgInfo = message.toMessageInfo();
        // 自己发的消息：先以"发送中"状态显示，messageSent 事件后更新为成功
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        final list = newMessages.putIfAbsent(convId, () => []);
        final existingIndex = list.indexWhere((m) => m.clientMsgId == message.clientMsgId);
        if (existingIndex >= 0) {
          list[existingIndex] = msgInfo;
        } else {
          list.add(msgInfo);
        }
        newMessages[convId] = List<MessageInfo>.from(list);
        this.state = this.state.copyWith(messages: newMessages);
      },
      messageSent: (
        clientMsgId,
        serverMsgId,
        sendTime,
        status,
        conversationId,
        sendId,
        recvId,
        groupId,
        sessionType,
        contentType,
        content,
        senderNickname,
        senderFaceUrl,
      ) {
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        final list = newMessages.putIfAbsent(conversationId, () => []);
        final existingIndex = list.indexWhere((m) => m.clientMsgId == clientMsgId);

        final msgInfo = messageSentToInfo(
          clientMsgId: clientMsgId,
          serverMsgId: serverMsgId,
          // sendTime 可能是秒或毫秒，自动检测转换
          sendTimeMs: _normalizeSendTime(sendTime.toInt()),
          status: status,
          conversationId: conversationId,
          sendId: sendId,
          recvId: recvId,
          groupId: groupId,
          sessionType: sessionType,
          contentType: contentType,
          content: content,
          senderNickname: senderNickname,
          senderFaceUrl: senderFaceUrl,
        );

        if (existingIndex >= 0) {
          list[existingIndex] = msgInfo;
        } else {
          list.add(msgInfo);
        }
        newMessages[conversationId] = List<MessageInfo>.from(list);
        this.state = this.state.copyWith(messages: newMessages);
      },
      messageSendFailed: (clientMsgId, error) {
        appLog.e('dart MessageService ❌ 消息发送失败: $clientMsgId, error=$error');
        // 更新消息列表中标记为发送失败
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        for (final entry in newMessages.entries) {
          final list = entry.value;
          for (int i = 0; i < list.length; i++) {
            if (list[i].clientMsgId == clientMsgId) {
              list[i] = MessageInfo(
                clientMsgId: list[i].clientMsgId,
                serverMsgId: list[i].serverMsgId,
                sendId: list[i].sendId,
                recvId: list[i].recvId,
                groupId: list[i].groupId,
                senderPlatformId: list[i].senderPlatformId,
                senderNickname: list[i].senderNickname,
                senderFaceUrl: list[i].senderFaceUrl,
                sessionType: list[i].sessionType,
                msgFrom: list[i].msgFrom,
                contentType: list[i].contentType,
                content: list[i].content,
                seq: list[i].seq,
                sendTime: list[i].sendTime,
                createTime: list[i].createTime,
                status: 3, // sendFailed
                isRead: list[i].isRead,
                attachedInfo: list[i].attachedInfo,
                ex: list[i].ex,
              );
              newMessages[entry.key] = List<MessageInfo>.from(list);
              break;
            }
          }
        }
        this.state = this.state.copyWith(messages: newMessages);
      },
      uploadProgress: (clientMsgId, progress, totalSize, uploadedSize) {
        appLog.d('[MessageService] 上传进度: $clientMsgId, $progress% '
            '(${uploadedSize.toInt()}/${totalSize.toInt()} bytes)');
      },
      messageRevoked: (conversationId, seq, clientMsgId, revokerId, revokerRole, revokerNickname, revokeTime, sourceMessageSendTime, sourceMessageSendId, sourceMessageSenderNickname, sessionType, isAdminRevoke) {
        // 使用真实昵称：优先 revokerNickname（可能为 ID），其次 sourceMessageSenderNickname
        final displayName = (revokerNickname.isNotEmpty && !revokerNickname.startsWith('6') && revokerNickname.length < 20)
            ? revokerNickname
            : sourceMessageSenderNickname.isNotEmpty
                ? sourceMessageSenderNickname
                : revokerNickname;
        appLog.i('dart MessageService 消息被撤回: conv=$conversationId, seq=$seq, msgId=$clientMsgId, revoker=$displayName');
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        final list = newMessages[conversationId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.clientMsgId == clientMsgId);
          if (idx >= 0) {
            final old = list[idx];
            list[idx] = MessageInfo(
              clientMsgId: old.clientMsgId,
              serverMsgId: old.serverMsgId,
              sendId: old.sendId,
              recvId: old.recvId,
              groupId: old.groupId,
              senderPlatformId: old.senderPlatformId,
              senderNickname: old.senderNickname,
              senderFaceUrl: old.senderFaceUrl,
              sessionType: old.sessionType,
              msgFrom: old.msgFrom,
              contentType: 2101, // 与 DB 中的撤回类型一致
              content: '{"revokerNickname":"$displayName","clientMsgID":"$clientMsgId","revokerID":"$revokerId","revokeTime":$revokeTime,"sessionType":$sessionType,"seq":$seq,"isAdminRevoke":$isAdminRevoke}',
              seq: old.seq,
              sendTime: old.sendTime,
              createTime: old.createTime,
              status: old.status,
              isRead: old.isRead,
              attachedInfo: old.attachedInfo,
              ex: old.ex,
            );
            newMessages[conversationId] = List<MessageInfo>.from(list);
            this.state = this.state.copyWith(messages: newMessages);
          }
        }
      },
      c2CReadReceipt: (receipts) {
        for (final receipt in receipts) {
          appLog.i('[READ] c2CReadReceipt: userId=${receipt.userId} msgIds=${receipt.msgIds}');
          int updatedCount = 0;
          final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
          for (final entry in newMessages.entries) {
            final list = entry.value;
            for (int i = 0; i < list.length; i++) {
              if (receipt.msgIds.contains(list[i].clientMsgId)) {
                appLog.i('[READ] 匹配消息: clientMsgId=${list[i].clientMsgId} wasRead=${list[i].isRead}');
                list[i] = MessageInfo(
                  clientMsgId: list[i].clientMsgId,
                  serverMsgId: list[i].serverMsgId,
                  sendId: list[i].sendId,
                  recvId: list[i].recvId,
                  groupId: list[i].groupId,
                  senderPlatformId: list[i].senderPlatformId,
                  senderNickname: list[i].senderNickname,
                  senderFaceUrl: list[i].senderFaceUrl,
                  sessionType: list[i].sessionType,
                  msgFrom: list[i].msgFrom,
                  contentType: list[i].contentType,
                  content: list[i].content,
                  seq: list[i].seq,
                  sendTime: list[i].sendTime,
                  createTime: list[i].createTime,
                  status: list[i].status,
                  isRead: true,
                  attachedInfo: list[i].attachedInfo,
                  ex: list[i].ex,
                );
                updatedCount++;
              }
            }
            newMessages[entry.key] = List<MessageInfo>.from(list);
          }
          this.state = this.state.copyWith(messages: newMessages);
          appLog.i('[READ] c2CReadReceipt updated=$updatedCount totalConv=${newMessages.length}');
        }
        // 刷新会话列表以同步未读数
        _loadConversations();
        appLog.i('[MessageService] C2C已读回执处理完成');
      },
      groupReadReceipt: (receipts) {
        for (final receipt in receipts) {
          final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
          final convId = receipt.groupId; // 群聊会话 ID
          final list = newMessages[convId];
          if (list != null) {
            for (int i = 0; i < list.length; i++) {
              if (list[i].clientMsgId == receipt.msgId) {
                list[i] = MessageInfo(
                  clientMsgId: list[i].clientMsgId,
                  serverMsgId: list[i].serverMsgId,
                  sendId: list[i].sendId,
                  recvId: list[i].recvId,
                  groupId: list[i].groupId,
                  senderPlatformId: list[i].senderPlatformId,
                  senderNickname: list[i].senderNickname,
                  senderFaceUrl: list[i].senderFaceUrl,
                  sessionType: list[i].sessionType,
                  msgFrom: list[i].msgFrom,
                  contentType: list[i].contentType,
                  content: list[i].content,
                  seq: list[i].seq,
                  sendTime: list[i].sendTime,
                  createTime: list[i].createTime,
                  status: list[i].status,
                  isRead: true,
                  attachedInfo: list[i].attachedInfo,
                  ex: list[i].ex,
                );
              }
            }
            newMessages[convId] = List<MessageInfo>.from(list);
          }
          this.state = this.state.copyWith(messages: newMessages);
        }
        appLog.i('[MessageService] 群聊已读回执处理完成');
      },
      messagesDeleted: (conversationId, clientMsgIds) {
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        final list = newMessages[conversationId];
        if (list != null) {
          final deletedSet = clientMsgIds.toSet();
          newMessages[conversationId] = list.where((m) => !deletedSet.contains(m.clientMsgId)).toList();
        }
        this.state = this.state.copyWith(messages: newMessages);
        _loadConversations(); // 刷新会话列表以更新 latestMsg
        appLog.i('[MessageService] 消息已删除: conv=$conversationId, count=${clientMsgIds.length}');
      },
      msgEdited: (message) {
        final convId = message.conversationId;
        if (convId.isEmpty) return;
        final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
        final list = newMessages[convId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.clientMsgId == message.clientMsgId);
          final msgInfo = message.toMessageInfo();
          if (idx >= 0) {
            list[idx] = msgInfo;
          }
          newMessages[convId] = List<MessageInfo>.from(list);
        }
        this.state = this.state.copyWith(messages: newMessages);
        appLog.i('[MessageService] 消息已编辑: conv=$convId, msgId=${message.clientMsgId}');
      },
      totalUnreadCountChanged: (count) {
        // 会话变更已由 conversationChanged 事件单独处理，无需重新加载全部会话
      },
      conversationUserInputStatusChanged: (data) {
        // 输入状态由 chat_detail_screen 直接处理
        appLog.d('[MessageService] 输入状态变化: conv=${data.conversationId}, user=${data.userId}');
      },
      recvOfflineNewMessage: (messages) {
        _loadConversations();
        for (final message in messages) {
          final convId = message.conversationId;
          if (convId.isEmpty) continue;
          if (message.sendId == this.state.currentUserId) continue;
          final msgInfo = message.toMessageInfo();
          final newMessages = Map<String, List<MessageInfo>>.from(this.state.messages);
          final list = newMessages.putIfAbsent(convId, () => []);
          list.add(msgInfo);
          newMessages[convId] = List<MessageInfo>.from(list);
          this.state = this.state.copyWith(messages: newMessages);
        }
      },
      // ---- 好友事件 ----
      friendAdded: (friends) {
        appLog.i('[MessageService] 好友新增: ${friends.length}人');
      },
      friendDeleted: (friendId) {
        appLog.i('[MessageService] 好友删除: $friendId');
      },
      friendInfoUpdated: (userId) {
        appLog.i('[MessageService] 好友信息更新: $userId');
        // 刷新该好友的用户资料缓存
        if (_client != null) {
          _client!.getUsersInfo(userIds: [userId]).then((list) {
            if (list.isNotEmpty) {
              final newProfiles = Map<String, UserInfo>.from(this.state.userProfiles);
              newProfiles[list.first.userId] = list.first;
              this.state = this.state.copyWith(userProfiles: newProfiles);
            }
          }).catchError((e) {
            appLog.w('[MessageService] 刷新好友资料失败: $e');
          });
        }
      },
      friendApplicationAdded: (application) {
        appLog.i('[MessageService] 好友申请新增');
      },
      friendApplicationApproved: (application) {
        appLog.i('[MessageService] 好友申请已同意');
      },
      friendApplicationRejected: (application) {
        appLog.i('[MessageService] 好友申请已拒绝');
      },
      // ---- 群组事件 ----
      groupCreated: (groupId) {
        appLog.i('[MessageService] 群组创建: $groupId');
        _loadConversations();
      },
      groupInfoChanged: (groupId) {
        appLog.i('[MessageService] 群信息变更: $groupId');
        _loadConversations();
      },
      groupMemberAdded: (groupId, memberIds) {
        appLog.i('[MessageService] 群成员新增: group=$groupId, count=${memberIds.length}');
      },
      groupMemberDeleted: (groupId, memberIds) {
        appLog.i('[MessageService] 群成员移除: group=$groupId, count=${memberIds.length}');
      },
      groupApplicationAdded: (application) {
        appLog.i('[MessageService] 入群申请新增');
      },
      groupApplicationApproved: (application) {
        appLog.i('[MessageService] 入群申请已同意');
        _loadConversations();
      },
      groupApplicationRejected: (application) {
        appLog.i('[MessageService] 入群申请已拒绝');
      },
      groupDismissed: (groupId) {
        appLog.i('[MessageService] 群已解散: $groupId');
        _loadConversations();
      },
      // ---- 用户事件 ----
      userInfoUpdated: (user) {
        final newProfiles = Map<String, UserInfo>.from(this.state.userProfiles);
        newProfiles[user.userId] = user;
        this.state = this.state.copyWith(userProfiles: newProfiles);
      },
      userStatusChanged: (userId, status, platformIds) {
        appLog.d('[MessageService] 用户状态变化: $userId, status=$status');
      },
      // ---- 黑名单事件 ----
      blackAdded: (userId) {
        appLog.i('[MessageService] 加入黑名单: $userId');
      },
      blackDeleted: (blackId) {
        appLog.i('[MessageService] 移出黑名单: $blackId');
      },
      // ---- 连接 / 认证事件 ----
      reconnecting: (attempt, maxAttempts) {
        appLog.i('[MessageService] 重连中: attempt=$attempt/$maxAttempts');
        this.state = this.state.copyWith(isConnected: false);
      },
      loginSuccess: (userId) {
        appLog.i('[MessageService] 登录成功: $userId');
      },
      logout: () {
        appLog.i('[MessageService] 已登出');
        this.state = const MessageServiceState();
      },
      orElse: () {},
    );
  }

  Future<void> _loadConversations() async {
    if (_client == null) {
      appLog.w('[MessageService] _loadConversations 跳过：client 为空');
      return;
    }

    try {
      final conversations = await _client!.getConversations();
      appLog.i('[MessageService] 加载会话列表，共 ${conversations.length} 条');
      this.state = this.state.copyWith(conversations: []);
      for (final conv in conversations) {
        _updateConversation(conv);
      }
      final userIds = conversations
          .where((c) => c.userId.isNotEmpty)
          .map((c) => c.userId)
          .toSet()
          .toList();
      unawaited(preloadUserProfiles(userIds));
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载会话列表失败: $e');
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
    await _eventStreamSubscription?.cancel();
    _eventStreamSubscription = null;
    await _client?.disconnect();
    _client = null;
    this.state = const MessageServiceState();
  }

  /// 标记会话为已读
  Future<void> markConversationAsRead(String conversationId) async {
    if (_client == null) return;
    try {
      // 从本地状态查找会话类型
      final conv = this.state.conversations.where((c) => c.conversationId == conversationId).firstOrNull;
      final sessionType = conv?.sessionType ?? SessionType.singleChat;
      appLog.i('[READ] Service 标记已读: sessionType=$sessionType');
      await _client!.markConversationAsRead(conversationId: conversationId, sessionType: sessionType);
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
