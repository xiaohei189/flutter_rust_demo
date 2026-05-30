import 'dart:async';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/models/chat.dart';
import 'package:flutter_rust_demo/models/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart';
import 'package:flutter_rust_demo/src/rust/domain/model/user.dart' show UserInfo;
import 'package:flutter_rust_demo/src/rust/infra/database/models.dart' show LocalConversation;
import 'package:flutter_rust_demo/src/rust/api/simple.dart' show initLogger;
import 'package:flutter_rust_demo/src/rust/domain/model/message.dart' show MessageInfo;
import 'package:flutter_rust_demo/utils/app_logger.dart';
import 'package:flutter_rust_demo/utils/login_storage.dart';

/// MessageService 的状态类
class MessageServiceState {
  final bool isConnected;
  final bool isSyncingConversations;
  final int syncProgress;
  final String currentUserId;
  final List<LocalConversation> conversations;
  final Map<String, List<Message>> messages;
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
    Map<String, List<Message>>? messages,
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
  OpenImBridgeClient? _client;
  StreamSubscription<dynamic>? _eventStreamSubscription;

  MessageServiceNotifier() : super(const MessageServiceState());

  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;

  /// 获取指定会话的消息列表
  List<Message> getMessages(String conversationId) {
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

  /// 批量预加载用户资料（用于会话/消息展示昵称与头像）
  /// 缓存逻辑由 Rust 侧 get_users_info 实现，Dart 直接传全部 userIds
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

  /// 更新当前登录用户资料（仅更新 patch 中传入字段），并回写缓存
  Future<UserInfo?> updateLoginUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
    int? globalRecvMsgOpt,
  }) async {
    if (_client == null) {
      // 尝试重新初始化（如果有保存的凭证）
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
      // 调用 Rust 层的更新方法（Rust 层使用 HTTP API）
      await _client!.updateUserProfile(
        nickname: nickname,
        faceUrl: faceUrl,
        ex: ex,
      );
      
      // 更新成功后，重新获取用户信息以确保状态一致性
      return await refreshLoginUserProfile();
    } catch (e) {
      appLog.e('[MessageService] 更新当前用户资料失败: $e');
      return null;
    }
  }

  /// 加载历史消息（首次加载或翻页）
  ///
  /// - `conversationId`: 会话 ID
  /// - `count`: 每次加载的消息数量
  /// - `startSeq`: 起始 seq（可选，用于翻页）
  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    int startSeq = 0,
  }) async {
    if (_client == null) return false;

    try {
      final result = await _client!.getHistoryMessages(
        req: GetHistoryMessagesReq(
          conversationId: conversationId,
          startSeq: startSeq,
          count: count,
        ),
      );

      if (result.isEmpty) {
        return false;
      }

      final messages = result
          .map((msg) => _msgDataToMessage(msg))
          .toList();

      final newMessages = Map<String, List<Message>>.from(this.state.messages);
      final currentMessages = newMessages.putIfAbsent(conversationId, () => []);

      currentMessages.insertAll(0, messages.reversed);

      final seenIds = <String>{};
      newMessages[conversationId] = currentMessages
          .where((msg) => seenIds.add(msg.id))
          .toList();

      this.state = this.state.copyWith(messages: newMessages);

      return result.length >= count;
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载历史消息失败: $e');
      return false;
    }
  }

  /// 将 MessageInfo 转换为 Message
  Message _msgDataToMessage(MessageInfo msg) {
    final clientMsgId = msg.clientMsgId;
    final sendId = msg.sendId;

    String content = msg.content;
    if (msg.contentType == 101 && content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        content = decoded['content'] as String? ?? content;
      } catch (_) {
        // keep raw content
      }
    }

    final sendTime = msg.sendTime.toInt();
    final isSent = sendId == this.state.currentUserId;

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

  /// 发送文本消息：先加入列表展示 -> 发送 -> 成功后更新状态
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

    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = Message(
      id: tempId,
      senderId: this.state.currentUserId,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isSent: true,
      sendStatus: MessageSendStatus.sending,
    );
    final newMessages = Map<String, List<Message>>.from(this.state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    list.add(optimisticMessage);
    this.state = this.state.copyWith(messages: newMessages);

    try {
      await _client!.sendMessage(
        req: SendMessageReq(
          recvId: recvId,
          groupId: groupId,
          sessionType: sessionType,
          contentType: 101, // 文本消息
          content: text,
        ),
      );
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
    final list = this.state.messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final newMessages = Map<String, List<Message>>.from(this.state.messages);
      newMessages[conversationId] = List<Message>.from(list);
      newMessages[conversationId]![index] = list[index].copyWith(sendStatus: status);
      this.state = this.state.copyWith(messages: newMessages);
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
      _client = await OpenImBridgeClient.newInstance(
        userId: resolvedUserId,
        token: resolvedImToken,
        platformId: 5,
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
        dataDir: dataDir,
      );
      appLog.i('[MessageService] newInstance 完成');

      // 立即加载本地缓存的会话列表
      appLog.i('[MessageService] 立即加载本地缓存的会话列表');
      unawaited(_loadConversations());

      _eventStreamSubscription = _client!.eventStream().listen(
        _handleEvent,
      );
      appLog.i('[MessageService] 流订阅已注册');

      appLog.i('[MessageService] 等待 300ms');
      await Future.delayed(const Duration(milliseconds: 300));
      appLog.i('[MessageService] 300ms 完成');

      // newInstance 内部已经完成了连接，这里直接标记为已连接
      this.state = this.state.copyWith(isConnected: true);

      appLog.i('✅ 客户端连接成功');
      await refreshLoginUserProfile();

      appLog.i('[MessageService] 触发 _loadConversations（不 await）');
      _loadConversations();
    } catch (e) {
      appLog.e('❌ 初始化失败: $e');
      this.state = this.state.copyWith(isConnected: false);
      rethrow;
    } finally {
      this.state = this.state.copyWith(isInitializing: false);
    }
  }

  /// 更新或添加会话
  void _updateConversation(LocalConversation conv) {
    final newConversations = List<LocalConversation>.from(this.state.conversations);
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
        return a.isPinned == 1 ? -1 : 1;
      }
      final aTime = a.latestMsgSendTime.toInt();
      final bTime = b.latestMsgSendTime.toInt();
      return bTime.compareTo(aTime);
    });

    this.state = this.state.copyWith(conversations: newConversations);
  }

  /// 处理统一事件（连接、会话、消息）
  void _handleEvent(dynamic event) {
    if (event == null) return;
    final name = event.runtimeType.toString();
    
    // 连接事件
    if (name.contains('ConnectSuccess') || name.contains('Connected')) {
      this.state = this.state.copyWith(isConnected: true);
      appLog.i('[MessageService] 连接成功，主动拉取一次会话列表');
      _loadConversations();
    } else if (name.contains('ConnectFailed') ||
        name.contains('KickedOffline') ||
        name.contains('UserTokenExpired') ||
        name.contains('UserTokenInvalid')) {
      this.state = this.state.copyWith(isConnected: false);
    }
    // 会话事件
    else if (name.contains('SyncStart') || name.contains('ConversationSyncStart')) {
      this.state = this.state.copyWith(isSyncingConversations: true, syncProgress: 0);
    } else if (name.contains('SyncFinish') || name.contains('ConversationSyncFinish')) {
      this.state = this.state.copyWith(isSyncingConversations: false, syncProgress: 100);
      _loadConversations();
    } else if (name.contains('SyncProgress') || name.contains('ConversationSyncProgress')) {
      this.state = this.state.copyWith(syncProgress: 50);
    } else if (name.contains('SyncFailed') || name.contains('ConversationSyncFailed')) {
      this.state = this.state.copyWith(isSyncingConversations: false);
    } else if (name.contains('NewConversation') || name.contains('ConversationChanged')) {
      _loadConversations();
    } else if (name.contains('ConversationsCleared')) {
      this.state = this.state.copyWith(conversations: []);
    }
    // 消息事件
    else if (name.contains('NewMessage') || name.contains('RecvMessage')) {
      _loadConversations();
    }
  }

  /// 加载会话列表
  Future<void> _loadConversations() async {
    if (_client == null) {
      appLog.w('[MessageService] _loadConversations 跳过：client 为空');
      return;
    }

    try {
      appLog.i('[MessageService] _loadConversations 开始 getConversations');
      final conversations = await _client!.getConversations();
      appLog.i(
        '[MessageService] getConversations 返回，共 ${conversations.length} 条',
      );
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

  /// 刷新会话列表（供下拉刷新等场景调用）
  Future<void> refreshConversations() async {
    await _loadConversations();
  }

  /// 从本地列表移除会话（左滑删除/长按删除时调用；服务端删除可后续对接 SDK）
  void removeConversation(String conversationId) {
    final newConversations = List<LocalConversation>.from(this.state.conversations);
    newConversations.removeWhere((c) => c.conversationId == conversationId);
    final newMessages = Map<String, List<Message>>.from(this.state.messages);
    newMessages.remove(conversationId);
    this.state = this.state.copyWith(
      conversations: newConversations,
      messages: newMessages,
    );
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _eventStreamSubscription?.cancel();
    _eventStreamSubscription = null;
    await _client?.disconnect();
    _client = null;
    this.state = const MessageServiceState();
  }
}
