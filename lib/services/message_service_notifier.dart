import 'dart:async';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_rust_demo/models/chat.dart';
import 'package:flutter_rust_demo/models/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart';
import 'package:flutter_rust_demo/src/rust/domain/config.dart';
import 'package:flutter_rust_demo/src/rust/domain/constant/enums.dart';
import 'package:flutter_rust_demo/src/rust/sdk/client/types.dart';
import 'package:flutter_rust_demo/src/rust/domain/model/user.dart' show UserInfo;
import 'package:flutter_rust_demo/src/rust/infra/database/models.dart' show LocalConversation;
import 'package:flutter_rust_demo/src/rust/api/simple.dart' show initLogger;
import 'package:flutter_rust_demo/src/rust/domain/model/message.dart' show MessageInfo, ReceivedMessage;
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

  Message _receivedMessageToMessage(ReceivedMessage msg) {
    final clientMsgId = msg.clientMsgId;
    final sendId = msg.sendId;

    String content = msg.content;
    if (msg.contentType == 101 && content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        content = decoded['content'] as String? ?? content;
      } catch (_) {
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
      senderNickname: msg.senderNickName,
      senderFaceUrl: msg.senderFaceUrl,
    );
  }

  Message _msgDataToMessage(MessageInfo msg) {
    final clientMsgId = msg.clientMsgId;
    final sendId = msg.sendId;

    String content = msg.content;
    if (msg.contentType == 101 && content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        content = decoded['content'] as String? ?? content;
      } catch (_) {
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
          contentType: ContentType.text,
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

      appLog.i('[MessageService] 等待 300ms');
      await Future.delayed(const Duration(milliseconds: 300));
      appLog.i('[MessageService] 300ms 完成');

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
  void _handleEvent(SdkEvent event) {
    event.maybeWhen(
      connected: () {
        this.state = this.state.copyWith(isConnected: true);
        appLog.i('[MessageService] 连接成功，主动拉取一次会话列表');
        _loadConversations();
      },
      connectFailed: (error) {
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
        _loadConversations();
      },
      conversationDeleted: (conversationIds) {
        _loadConversations();
      },
            newMessage: (message) {
        _loadConversations();
        final convId = message.conversationId;
        if (convId.isEmpty) return;
        final msg = _receivedMessageToMessage(message);
        final newMessages = Map<String, List<Message>>.from(this.state.messages);
        final list = newMessages.putIfAbsent(convId, () => []);
        list.add(msg);
        newMessages[convId] = List<Message>.from(list);
        this.state = this.state.copyWith(messages: newMessages);
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

  Future<void> refreshConversations() async {
    await _loadConversations();
  }

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

  Future<void> disconnect() async {
    await _eventStreamSubscription?.cancel();
    _eventStreamSubscription = null;
    await _client?.disconnect();
    _client = null;
    this.state = const MessageServiceState();
  }
}