import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/rust/constant/enums.dart';
import '../../../src/rust/model/message.dart' show MessageInfo;
import '../../../src/rust/model/msg_struct.dart' show MsgStruct;
import '../../../providers/message_service_provider.dart';
import 'message_service_notifier.dart';

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

  MessageInfo? get latestMessage =>
      messages.isNotEmpty ? messages.last : null;

  MessageInfo? get earliestMessage =>
      messages.isNotEmpty ? messages.first : null;
}

/// 消息列表 ViewModel（按会话）
class MessageListNotifier extends FamilyNotifier<MessageListState, String> {
  MessageServiceNotifier? _messageService;
  StreamSubscription<MessageServiceState>? _serviceSubscription;

  @override
  MessageListState build(String conversationId) {
    _messageService = ref.read(messageServiceProvider.notifier);
    _serviceSubscription = _messageService!.stream.listen((_) => _syncState());
    ref.onDispose(() => _serviceSubscription?.cancel());
    Future.microtask(_syncState);
    return const MessageListState();
  }

  void _syncState() {
    final messages = _messageService!.getMessages(arg);
    state = state.copyWith(messages: messages);
  }

  void resetLoadState() {
    state = state.copyWith(hasMore: true, isLoading: false, error: null);
  }

  Future<bool> loadHistoryMessages({
    int count = 20,
    String startClientMsgId = '',
  }) async {
    if (state.isLoading || !state.hasMore) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final hasMore = await _messageService!.loadHistoryMessages(
        arg,
        count: count,
        startClientMsgId: startClientMsgId,
      );
      _syncState();
      state = state.copyWith(isLoading: false, hasMore: hasMore);
      return hasMore;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载历史消息失败: $e');
      return false;
    }
  }

  Future<bool> sendTextMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendTextMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
        conversationId: arg,
        groupId: groupId ?? '',
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送消息失败: $e');
      return false;
    }
  }

  Future<bool> sendMarkdownMessage({
    required String recvId,
    required String text,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendMarkdownMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
        conversationId: arg,
        groupId: groupId ?? '',
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送消息失败: $e');
      return false;
    }
  }

  Future<bool> sendAtTextMessage({
    required String recvId,
    required String text,
    required List<String> atUserIds,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendAtTextMessage(
        recvId: recvId,
        text: text,
        atUserIds: atUserIds,
        sessionType: sessionType,
        conversationId: arg,
        groupId: groupId ?? '',
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送 @ 消息失败: $e');
      return false;
    }
  }

  void _addSentMessage(MsgStruct result) {
    _messageService!.upsertSentMessage(arg, result);
    _syncState();
  }

  String _sourceId(String recvId, String? groupId) =>
      (groupId != null && groupId.isNotEmpty) ? groupId : recvId;

  Future<bool> sendImageMessage({
    required String recvId,
    required String filePath,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendImageMessage(
        filePath: filePath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送图片失败: $e');
      return false;
    }
  }

  Future<bool> sendVideoMessage({
    required String recvId,
    required String videoPath,
    required String snapshotPath,
    required SessionType sessionType,
    required int duration,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendVideoMessage(
        videoPath: videoPath,
        snapshotPath: snapshotPath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
        duration: duration,
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送视频失败: $e');
      return false;
    }
  }

  Future<bool> sendSoundMessage({
    required String recvId,
    required String filePath,
    required SessionType sessionType,
    required int duration,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendSoundMessage(
        filePath: filePath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
        duration: duration,
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送语音失败: $e');
      return false;
    }
  }

  Future<bool> sendFileMessage({
    required String recvId,
    required String filePath,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendFileMessage(
        filePath: filePath,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送文件失败: $e');
      return false;
    }
  }

  Future<bool> sendLocationMessage({
    required String recvId,
    required String description,
    required double latitude,
    required double longitude,
    required SessionType sessionType,
    String? groupId,
  }) async {
    try {
      final result = await _messageService!.sendLocationMessage(
        description: description,
        latitude: latitude,
        longitude: longitude,
        sourceId: _sourceId(recvId, groupId),
        sessionType: sessionType,
      );
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送位置失败: $e');
      return false;
    }
  }

  Future<bool> resendMessage({
    required MessageInfo message,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    try {
      final result = await _messageService!.resendMessage(
        message: message,
        sourceId: sourceId,
        sessionType: sessionType,
      );
      _messageService!.removeMessage(arg, message.clientMsgId);
      _addSentMessage(result);
      return true;
    } catch (e) {
      state = state.copyWith(error: '消息重发失败: $e');
      return false;
    }
  }
}
