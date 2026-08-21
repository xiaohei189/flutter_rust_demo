import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;
import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;
import 'package:flutter_rust_demo/generated/rust/constant/enums.dart'
    show SessionType;

import 'message_service_notifier.dart';

/// 消息发送、转发、撤回、删除、重发与本地搜索。
class MessageSendController {
  MessageSendController(this.service, this.repository, this.imClient);

  final MessageServiceNotifier service;
  final MessageRepository repository;
  final ImClient imClient;

  bool get _isClientReady => imClient.isInitialized;

  SessionType _toSdkSessionType(ChatSessionType type) =>
      SessionType.values[type.index];

  Future<ChatMessage> sendTextMessage({
    required String recvId,
    required String text,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    if (recvId.trim().isEmpty && groupId.trim().isEmpty) {
      throw ArgumentError('recvId 与 groupId 至少填一个');
    }

    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return repository.sendTextMessage(
      text: text,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送 Markdown 消息
  Future<ChatMessage> sendMarkdownMessage({
    required String recvId,
    required String text,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return repository.sendMarkdownMessage(
      text: text,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送 @ 提及消息
  Future<ChatMessage> sendAtTextMessage({
    required String text,
    required List<String> atUserIds,
    required String recvId,
    required ChatSessionType sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    final sourceId = groupId.isNotEmpty ? groupId : recvId;
    return repository.sendAtTextMessage(
      text: text,
      atUserIds: atUserIds,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 搜索当前会话的本地消息
  Future<List<MessageSearchResult>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
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
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    await repository.forwardMessage(
      clientMsgId: clientMsgId,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送图片消息
  Future<ChatMessage> sendImageMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendImageMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送 URL 图片（如 GIF，内容已上传，不走 OSS）
  Future<ChatMessage> sendImageMessageFromUrl({
    required String sourceUrl,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendImageMessageFromUrl(
      sourceUrl: sourceUrl,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送视频消息
  Future<ChatMessage> sendVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required String sourceId,
    required ChatSessionType sessionType,
    required int duration,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendVideoMessage(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
      duration: duration,
    );
  }

  /// 发送语音消息
  Future<ChatMessage> sendSoundMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
    required int duration,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendSoundMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
      duration: duration,
    );
  }

  /// 发送文件消息
  Future<ChatMessage> sendFileMessage({
    required String filePath,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendFileMessage(
      filePath: filePath,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送位置消息
  Future<ChatMessage> sendLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendLocationMessage(
      description: description,
      latitude: latitude,
      longitude: longitude,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送表情消息
  Future<ChatMessage> sendFaceMessage({
    required int index,
    required String data,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendFaceMessage(
      index: index,
      data: data,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送名片消息
  Future<ChatMessage> sendCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendCardMessage(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 发送引用消息
  Future<ChatMessage> sendQuoteMessage({
    required String text,
    required String sourceId,
    required ChatSessionType sessionType,
    required String quoteText,
    required String quoteClientMsgId,
    required String quoteSendId,
    required int quoteSendTime,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.sendQuoteMessage(
      text: text,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
      quoteText: quoteText,
      quoteClientMsgId: quoteClientMsgId,
      quoteSendId: quoteSendId,
      quoteSendTime: quoteSendTime,
    );
  }

  /// 发送正在输入状态
  Future<void> sendTyping({
    required String sourceId,
    required ChatSessionType sessionType,
    required bool focus,
  }) {
    return repository.sendTyping(
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
      focus: focus,
    );
  }

  /// 合并转发
  Future<void> sendMergerMessage({
    required List<String> clientMsgIds,
    required String sourceConversationId,
    required String title,
    required List<String> summaryList,
    required String sourceId,
    required ChatSessionType sessionType,
  }) {
    return repository.sendMergerMessage(
      clientMsgIds: clientMsgIds,
      sourceConversationId: sourceConversationId,
      title: title,
      summaryList: summaryList,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }

  /// 撤回消息
  Future<void> revokeMessage({
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    await repository.revokeMessage(
      conversationId: conversationId,
      userId: service.currentState.currentUserId,
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
    if (!_isClientReady) throw StateError('客户端未初始化');
    await repository.deleteMessage(
      conversationId: conversationId,
      clientMsgId: clientMsgId,
    );
  }

  /// 重发一条发送失败的消息（Rust 侧会生成新 clientMsgId）。
  Future<ChatMessage> resendMessage({
    required ChatMessage message,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    if (!_isClientReady) throw StateError('客户端未初始化');
    return repository.resendMessage(
      message: message,
      sourceId: sourceId,
      sessionType: _toSdkSessionType(sessionType),
    );
  }
}
