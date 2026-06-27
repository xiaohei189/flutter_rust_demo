import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/domain/model/message.dart' show MessageInfo;
import '../services/message_service_notifier.dart';
import '../src/rust/domain/constant/enums.dart';
import 'message_service_provider.dart';

/// 消息列表状态
class MessageListState {
  final List<MessageInfo> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const MessageListState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  MessageListState copyWith({
    List<MessageInfo>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return MessageListState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }

  /// 获取最新消息
  MessageInfo? get latestMessage => messages.isNotEmpty ? messages.last : null;

  /// 获取最早消息
  MessageInfo? get earliestMessage => messages.isNotEmpty ? messages.first : null;
}

/// 消息列表 Notifier（按会话）
class MessageListNotifier extends StateNotifier<MessageListState> {
  MessageListNotifier(this._messageService, this._conversationId)
      : super(const MessageListState()) {
    _init();
  }

  final MessageServiceNotifier _messageService;
  final String _conversationId;
  StreamSubscription<MessageServiceState>? _serviceSubscription;

  void _init() {
    _syncState();
    _serviceSubscription = _messageService.stream.listen((_) => _syncState());
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }

  void _syncState() {
    final messages = _messageService.getMessages(_conversationId);
    state = state.copyWith(messages: messages);
  }

  /// 重置加载状态（进入会话时调用）
  void resetLoadState() {
    state = state.copyWith(hasMore: true, isLoading: false, error: null);
  }

  /// 加载历史消息
  Future<bool> loadHistoryMessages({
    int count = 20,
    String startClientMsgId = '',
  }) async {
    if (state.isLoading || !state.hasMore) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final hasMore = await _messageService.loadHistoryMessages(
        _conversationId,
        count: count,
        startClientMsgId: startClientMsgId,
      );

      _syncState();
      state = state.copyWith(
        isLoading: false,
        hasMore: hasMore,
      );
      return hasMore;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载历史消息失败: $e',
      );
      return false;
    }
  }

  /// 发送文本消息
  Future<bool> sendTextMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      await _messageService.sendTextMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
        conversationId: _conversationId,
        groupId: groupId ?? '',
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送消息失败: $e');
      return false;
    }
  }

  /// 发送 Markdown 消息
  Future<bool> sendMarkdownMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      await _messageService.sendMarkdownMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
        conversationId: _conversationId,
        groupId: groupId ?? '',
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送消息失败: $e');
      return false;
    }
  }

  /// 通用发送辅助：统一 sourceId 计算 + 错误处理
  String _sourceId(String recvId, String? groupId) =>
      (groupId != null && groupId.isNotEmpty) ? groupId : recvId;

  /// 发送图片消息
  Future<bool> sendImageMessage({
    required String recvId,
    required String filePath,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      await _messageService.sendImageMessage(
        filePath: filePath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送图片失败: $e');
      return false;
    }
  }

  /// 发送视频消息
  Future<bool> sendVideoMessage({
    required String recvId,
    required String videoPath,
    required String snapshotPath,
    required SessionType sessionType,
    required int duration,
    String? groupId,
  }) async {
    try {
      await _messageService.sendVideoMessage(
        videoPath: videoPath,
        snapshotPath: snapshotPath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
        duration: duration,
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送视频失败: $e');
      return false;
    }
  }

  /// 发送语音消息
  Future<bool> sendSoundMessage({
    required String recvId,
    required String filePath,
    required SessionType sessionType,
    required int duration,
    String? groupId,
  }) async {
    try {
      await _messageService.sendSoundMessage(
        filePath: filePath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
        duration: duration,
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送语音失败: $e');
      return false;
    }
  }

  /// 发送文件消息
  Future<bool> sendFileMessage({
    required String recvId,
    required String filePath,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      await _messageService.sendFileMessage(
        filePath: filePath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送文件失败: $e');
      return false;
    }
  }

  /// 发送位置消息
  Future<bool> sendLocationMessage({
    required String recvId,
    required String description,
    required double latitude,
    required double longitude,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      await _messageService.sendLocationMessage(
        description: description,
        latitude: latitude,
        longitude: longitude,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
      );
      _syncState();
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送位置失败: $e');
      return false;
    }
  }
}

/// 消息列表 Provider（按会话 ID）
final messageListProvider = StateNotifierProvider.family<MessageListNotifier, MessageListState, String>(
  (ref, conversationId) {
    return MessageListNotifier(
      ref.read(messageServiceProvider.notifier),
      conversationId,
    );
  },
);

/// 指定会话的消息列表 Provider（便捷访问）
final messagesByConversationIdProvider = Provider.family<List<MessageInfo>, String>((ref, conversationId) {
  return ref.watch(messageListProvider(conversationId)).messages;
});
