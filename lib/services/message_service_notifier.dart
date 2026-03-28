import 'dart:async';

import 'package:flutter_rust_demo/models/chat.dart';
import 'package:flutter_rust_demo/models/message.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart';
import 'package:flutter_rust_demo/src/rust/api/simple.dart';
import 'package:flutter_rust_demo/src/rust/im/client/listeners.dart'
    show AdvancedMsgEvent, ConversationEvent;
import 'package:flutter_rust_demo/src/rust/im/model/conversation.dart' as im_conv;
import 'package:flutter_rust_demo/src/rust/im/model/message.dart' as im_msg;
import 'package:flutter_rust_demo/utils/app_logger.dart';

/// MessageService 的状态类
class MessageServiceState {
  final bool isConnected;
  final bool isSyncingConversations;
  final int syncProgress;
  final String currentUserId;
  final List<im_conv.LocalConversation> conversations;
  final Map<String, List<Message>> messages;
  final Map<String, UserProfile> userProfiles;
  final UserProfile? loginUserProfile;
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
    List<im_conv.LocalConversation>? conversations,
    Map<String, List<Message>>? messages,
    Map<String, UserProfile>? userProfiles,
    UserProfile? loginUserProfile,
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
  OpenImBridgeClient? _client;
  StreamSubscription<dynamic>? _connStreamSubscription;
  StreamSubscription<dynamic>? _conversationStreamSubscription;
  StreamSubscription<dynamic>? _advancedMsgStreamSubscription;

  MessageServiceNotifier() : super(const MessageServiceState());

  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;

  /// 获取指定会话的消息列表
  List<Message> getMessages(String conversationId) {
    return List.unmodifiable(state.messages[conversationId] ?? []);
  }

  /// 获取指定用户资料（命中缓存时）
  UserProfile? getUserProfile(String userId) => state.userProfiles[userId];

  /// 拉取当前登录用户资料（通过批量接口 getUsersInfo，走缓存）并更新内存缓存
  Future<UserProfile?> refreshLoginUserProfile() async {
    if (_client == null || state.currentUserId.isEmpty) return null;
    try {
      final list = await _client!.getUsersInfo(userIds: [state.currentUserId]);
      final profile = list.isNotEmpty ? list.first : null;
      if (profile != null) {
        final newUserProfiles = Map<String, UserProfile>.from(state.userProfiles);
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

  /// 批量预加载用户资料（用于会话/消息展示昵称与头像）
  /// 缓存逻辑由 Rust 侧 get_users_info 实现，Dart 直接传全部 userIds
  Future<void> preloadUserProfiles(List<String> userIds) async {
    if (_client == null || userIds.isEmpty) return;
    final uniq = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uniq.isEmpty) return;
    try {
      final list = await _client!.getUsersInfo(userIds: uniq);
      final newUserProfiles = Map<String, UserProfile>.from(state.userProfiles);
      for (final p in list) {
        newUserProfiles[p.userId] = p;
      }
      state = state.copyWith(userProfiles: newUserProfiles);
    } catch (e) {
      appLog.w('[MessageService] 批量拉取用户资料失败: $e');
    }
  }

  /// 更新当前登录用户资料（仅更新 patch 中指定字段），并回写缓存
  Future<UserProfile?> updateLoginUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
    int? globalRecvMsgOpt,
  }) async {
    if (_client == null) return null;
    try {
      final updated = await _client!.updateLoginUserProfile(
        patch: UserProfilePatch(
          nickname: nickname,
          faceUrl: faceUrl,
          ex: ex,
          globalRecvMsgOpt: globalRecvMsgOpt,
        ),
      );
      final newUserProfiles = Map<String, UserProfile>.from(state.userProfiles);
      newUserProfiles[updated.userId] = updated;
      state = state.copyWith(
        loginUserProfile: updated,
        userProfiles: newUserProfiles,
      );
      return updated;
    } catch (e) {
      appLog.e('[MessageService] 更新当前用户资料失败: $e');
      return null;
    }
  }

  /// 加载历史消息（首次加载或翻页）
  ///
  /// 完全参考 Go SDK 的 GetAdvancedHistoryMessageList 实现
  /// - `conversationId`: 会话 ID
  /// - `count`: 每次加载的消息数量
  /// - `startClientMsgId`: 起始消息ID（可选，用于翻页，获取比这个消息更早的消息）
  /// - 返回: 是否还有更多消息
  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    String? startClientMsgId,
  }) async {
    if (_client == null) return false;

    try {
      final req = im_msg.GetAdvancedHistoryMessageListParams(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId ?? '',
        count: count,
        viewType: 0,
      );

      final result = await _client!.getAdvancedHistoryMessageList(req: req);

      if (result.errCode != 0) {
        appLog.w(
          'dart MessageService ❌ 加载历史消息失败: ${result.errMsg} (code: ${result.errCode})',
        );
        return false;
      }

      if (result.messageList.isEmpty) {
        return false;
      }

      final messages = result.messageList
          .map((msg) => _msgStructToMessage(msg))
          .toList();

      final newMessages = Map<String, List<Message>>.from(state.messages);
      final currentMessages = newMessages.putIfAbsent(conversationId, () => []);

      currentMessages.insertAll(0, messages.reversed);

      final seenIds = <String>{};
      newMessages[conversationId] = currentMessages
          .where((msg) => seenIds.add(msg.id))
          .toList();

      state = state.copyWith(messages: newMessages);

      return !result.isEnd;
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载历史消息失败: $e');
      return false;
    }
  }

  /// 将 MsgStruct 转换为 Message
  Message _msgStructToMessage(im_msg.MsgStruct msg) {
    final clientMsgId = msg.clientMsgId ?? '';
    final sendId = msg.sendId ?? '';

    String content = '';
    if (msg.textElem != null) {
      content = msg.textElem!.content;
    } else if (msg.content != null) {
      final raw = msg.content!;
      if (msg.contentType == 101 && raw.startsWith('{')) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          content = decoded['content'] as String? ?? raw;
        } catch (_) {
          content = raw;
        }
      } else {
        content = raw;
      }
    }

    final sendTime = msg.sendTime.toInt();
    final isSent = sendId == state.currentUserId;

    return Message(
      id: clientMsgId.isNotEmpty
          ? clientMsgId
          : DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: sendId,
      content: content,
      type: MessageType.text,
      timestamp: sendTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(sendTime)
          : DateTime.now(),
      isSent: isSent,
      senderNickname: msg.senderNickname,
      senderFaceUrl: msg.senderFaceUrl,
    );
  }

  /// 发送文本消息：先创建消息 -> 加入列表展示 -> 发送 -> 成功后更新状态
  /// [conversationId] 必填，用于把乐观消息加入该会话列表
  /// [groupId] 群聊时传群 ID，单聊传空字符串
  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required int sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (_client == null) {
      throw StateError('客户端未初始化');
    }
    if (recvId.trim().isEmpty && groupId.trim().isEmpty) {
      throw ArgumentError('recvId 与 groupId 至少填一个');
    }

    final msgData = await _client!.createTextMessage(
      text: text,
      recvId: recvId,
      groupId: groupId,
      sessionType: sessionType,
    );

    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = Message(
      id: tempId,
      senderId: state.currentUserId,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isSent: true,
      sendStatus: MessageSendStatus.sending,
    );
    final newMessages = Map<String, List<Message>>.from(state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    list.add(optimisticMessage);
    state = state.copyWith(messages: newMessages);

    try {
      await _client!.sendMessage(msg: msgData, isOnlineOnly: false);
      _updateMessageSendStatus(conversationId, tempId, MessageSendStatus.sent);
    } catch (e) {
      appLog.e('dart MessageService 发送失败: $e');
      _updateMessageSendStatus(
        conversationId,
        tempId,
        MessageSendStatus.failed,
      );
      rethrow;
    }
  }

  void _updateMessageSendStatus(
    String conversationId,
    String messageId,
    MessageSendStatus status,
  ) {
    final list = state.messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final newMessages = Map<String, List<Message>>.from(state.messages);
      newMessages[conversationId] = List<Message>.from(list);
      newMessages[conversationId]![index] = list[index].copyWith(sendStatus: status);
      state = state.copyWith(messages: newMessages);
    }
  }

  /// 初始化并连接服务
  ///
  /// [wsUrl] WebSocket 地址（可选，默认 localhost:10001）。
  /// [apiBaseUrl] HTTP API 基础地址（可选，默认 localhost:10002；Android 等可传单独地址）。
  /// [userId] / [imToken] 若都传入则使用本地凭证连接，不调登录接口；否则需在调用前通过登录页获取并传入。
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

      state = state.copyWith(currentUserId: resolvedUserId);

      appLog.i('[MessageService] 即将调用 OpenImBridgeClient.newInstance');
      _client = await OpenImBridgeClient.newInstance(
        userId: resolvedUserId,
        token: resolvedImToken,
        platformId: 5,
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
      );
      appLog.i('[MessageService] newInstance 完成');

      _advancedMsgStreamSubscription = _client!.advancedMsgStream().listen(
        _handleAdvancedMsgEvent,
      );
      _connStreamSubscription = _client!.connStream().listen(_handleConnEvent);
      _conversationStreamSubscription = _client!.conversationStream().listen(
        _handleConversationEvent,
      );
      appLog.i('[MessageService] 流订阅已注册');

      appLog.i('[MessageService] 等待 300ms');
      await Future.delayed(const Duration(milliseconds: 300));
      appLog.i('[MessageService] 300ms 完成');

      appLog.i('[MessageService] 即将调用 connect()');
      await _client!.connect();
      appLog.i('[MessageService] connect() 返回');
      state = state.copyWith(isConnected: true);

      appLog.i('✅ 客户端连接成功');
      await refreshLoginUserProfile();

      appLog.i('[MessageService] 触发 _loadConversations（不 await）');
      _loadConversations();
    } catch (e) {
      appLog.e('❌ 初始化失败: $e');
      state = state.copyWith(isConnected: false);
      rethrow;
    } finally {
      state = state.copyWith(isInitializing: false);
    }
  }

  /// 更新或添加会话
  void _updateConversation(im_conv.LocalConversation conv) {
    final newConversations = List<im_conv.LocalConversation>.from(state.conversations);
    final index = newConversations.indexWhere(
      (c) => c.conversationId == conv.conversationId,
    );

    if (index >= 0) {
      newConversations[index] = conv;
    } else {
      newConversations.add(conv);
    }

    newConversations.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final aTime = a.latestMsgSendTime.toInt();
      final bTime = b.latestMsgSendTime.toInt();
      return bTime.compareTo(aTime);
    });

    state = state.copyWith(conversations: newConversations);
  }

  /// 处理连接状态事件
  void _handleConnEvent(dynamic event) {
    if (event == null) return;
    final name = event.runtimeType.toString();
    if (name.contains('ConnectSuccess') || name == 'ConnEvent_ConnectSuccess') {
      state = state.copyWith(isConnected: true);
      appLog.i('[MessageService] 连接成功，主动拉取一次会话列表');
      _loadConversations();
    } else if (name.contains('ConnectFailed') ||
        name.contains('KickedOffline') ||
        name.contains('UserTokenExpired') ||
        name.contains('UserTokenInvalid')) {
      state = state.copyWith(isConnected: false);
    }
  }

  /// 处理会话事件（同步进度、新会话、会话变更等）
  void _handleConversationEvent(ConversationEvent event) {
    event.when(
      syncServerStart: (_) {
        state = state.copyWith(
          isSyncingConversations: true,
          syncProgress: 0,
        );
      },
      syncServerFinish: (_) {
        appLog.i('[MessageService] 收到 syncServerFinish，拉取会话列表');
        state = state.copyWith(
          isSyncingConversations: false,
          syncProgress: 100,
        );
        _loadConversations();
      },
      syncServerProgress: (progress) {
        state = state.copyWith(syncProgress: progress);
      },
      syncServerFailed: (_) {
        state = state.copyWith(isSyncingConversations: false);
      },
      newConversation: (list) {
        for (final c in list) {
          _updateConversation(c);
        }
      },
      conversationChanged: (list) {
        for (final c in list) {
          _updateConversation(c);
        }
      },
      conversationsCleared: (_) {},
      totalUnreadMessageCountChanged: (_) {},
      conversationUserInputStatusChanged: (typing) {
        appLog.d(
          '👤 用户输入状态回调 conversationId=${typing.conversationId} sendId=${typing.sendId} msgTip=${typing.msgTip}',
        );
      },
    );
  }

  /// 处理消息变动事件（新消息、已读回执、撤回等）
  void _handleAdvancedMsgEvent(AdvancedMsgEvent event) {
    appLog.d('📩 收到消息事件: ${event.runtimeType}');
    try {
      event.when(
        recvNewMessage: (msg) {
          _appendMsgStructToMessages(msg);
        },
        recvC2CReadReceipt: (_) {},
        recvGroupReadReceipt: (_) {},
        newRecvMessageRevoked: (_) {},
        recvOfflineNewMessage: (msg) {
          _appendMsgStructToMessages(msg);
        },
        msgDeleted: (_) {},
        recvOnlineOnlyMessage: (msg) {
          _appendMsgStructToMessages(msg);
        },
      );
    } catch (e) {
      appLog.e('dart MessageService 处理消息事件失败: $e');
    }
  }

  void _appendMsgStructToMessages(im_msg.MsgStruct msg) {
    final conversationId = _msgStructToConversationId(msg);
    if (conversationId.isEmpty) return;
    final newMessages = Map<String, List<Message>>.from(state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    list.add(_msgStructToMessage(msg));
    state = state.copyWith(messages: newMessages);
  }

  /// 与 Rust conversation_id_by_session_type 一致：单聊 si_{uid1}_{uid2} 排序，群聊 sg_{groupId}，其他 g_{groupId}
  String _msgStructToConversationId(im_msg.MsgStruct msg) {
    final sessionType = msg.sessionType;
    final sendId = msg.sendId ?? '';
    final recvId = msg.recvId ?? '';
    final groupId = msg.groupId ?? '';
    if (sessionType == 1) {
      final my = state.currentUserId;
      if (my.isEmpty) return '';
      final other = sendId == my ? recvId : sendId;
      if (other.isEmpty) return '';
      final parts = [my, other]..sort();
      return 'si_${parts[0]}_${parts[1]}';
    }
    if (sessionType == 2) return 'sg_$groupId';
    if (sessionType == 3) return 'sg_$groupId';
    if (groupId.isNotEmpty) return 'g_$groupId';
    return '';
  }

  /// 加载会话列表
  Future<void> _loadConversations() async {
    if (_client == null) {
      appLog.w('[MessageService] _loadConversations 跳过：client 为空');
      return;
    }

    try {
      appLog.i('[MessageService] _loadConversations 开始 getAllConversations');
      final conversations = await _client!.getAllConversations();
      appLog.i(
        '[MessageService] getAllConversations 返回，共 ${conversations.length} 条',
      );
      state = state.copyWith(conversations: []);
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

  /// 刷新会话列表（供下拉刷新等场景调用）
  Future<void> refreshConversations() async {
    await _loadConversations();
  }

  /// 从本地列表移除会话（左滑删除/长按删除时调用；服务端删除可后续对接 SDK）
  void removeConversation(String conversationId) {
    final newConversations = List<im_conv.LocalConversation>.from(state.conversations);
    newConversations.removeWhere((c) => c.conversationId == conversationId);
    final newMessages = Map<String, List<Message>>.from(state.messages);
    newMessages.remove(conversationId);
    state = state.copyWith(
      conversations: newConversations,
      messages: newMessages,
    );
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _client?.disconnect();
    _connStreamSubscription?.cancel();
    _conversationStreamSubscription?.cancel();
    _advancedMsgStreamSubscription?.cancel();
    _connStreamSubscription = null;
    _conversationStreamSubscription = null;
    _advancedMsgStreamSubscription = null;
    _client = null;
    state = const MessageServiceState();
  }

  @override
  void dispose() {
    _connStreamSubscription?.cancel();
    _conversationStreamSubscription?.cancel();
    _advancedMsgStreamSubscription?.cancel();
    super.dispose();
  }
}
