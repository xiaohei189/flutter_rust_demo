import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart' show Message;
import '../services/message_service_notifier.dart';
import '../src/rust/domain/constant/enums.dart';
import 'message_service_provider.dart';

/// 消息列表状态
class MessageListState {
  final List<Message> messages;
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
    List<Message>? messages,
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
  Message? get latestMessage => messages.isNotEmpty ? messages.last : null;

  /// 获取最早消息
  Message? get earliestMessage => messages.isNotEmpty ? messages.first : null;
}

/// 消息列表 Notifier（按会话）
class MessageListNotifier extends StateNotifier<MessageListState> {
  MessageListNotifier(this._messageService, this._conversationId)
      : super(const MessageListState()) {
    _init();
  }

  final MessageServiceNotifier _messageService;
  final String _conversationId;

  void _init() {
    _syncState();
  }

  void _syncState() {
    final messages = _messageService.getMessages(_conversationId);
    state = state.copyWith(messages: messages);
  }

  /// 加载历史消息
  Future<bool> loadHistoryMessages({
    int count = 20,
    int startSeq = 0,
  }) async {
    if (state.isLoading || !state.hasMore) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final hasMore = await _messageService.loadHistoryMessages(
        _conversationId,
        count: count,
        startSeq: startSeq,
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
final messagesByConversationIdProvider = Provider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(messageListProvider(conversationId)).messages;
});
