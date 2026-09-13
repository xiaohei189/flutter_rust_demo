import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;
import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;
import 'package:flutter_rust_demo/generated/rust/constant/enums.dart'
    show SessionType;

import 'message_service_notifier.dart';

/// 转发、合并转发、正在输入、撤回、删除与本地搜索。
///
/// 发送（含乐观上屏与状态收敛）统一走 [MessageSendPipeline]，本类不再承担。
class MessageSendController {
  MessageSendController(this.service, this.repository, this.imClient);

  final MessageServiceNotifier service;
  final MessageRepository repository;
  final ImClient imClient;

  bool get _isClientReady => imClient.isInitialized;

  SessionType _toSdkSessionType(ChatSessionType type) =>
      SessionType.values[type.index];

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
}
