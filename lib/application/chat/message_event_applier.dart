import 'dart:async';
import 'dart:convert';

import 'package:flutter_rust_demo/data/mappers/message_mapper.dart'
    show messageFromMessageInfo;
import 'package:flutter_rust_demo/data/services/app_lifecycle_service.dart';
import 'package:flutter_rust_demo/data/services/local_notification_service.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/generated/rust/model/local.dart'
    show LocalConversation;
import 'package:flutter_rust_demo/generated/rust/model/message.dart'
    show MessageInfo;
import 'package:flutter_rust_demo/generated/rust/event/events/message.dart'
    show MessageReceipt;
import 'package:flutter_rust_demo/core/utils/app_logger.dart';

import 'message_service_notifier.dart';
import 'message_service_reducer.dart';

/// 消息事件应用：把 SDK 事件落到 State（撤回、回执、删除、失败、进度、追加、会话更新）。
class MessageEventApplier {
  MessageEventApplier(
    this.service,
    this.appLifecycleService,
    this.localNotificationService,
  );

  final MessageServiceNotifier service;
  final AppLifecycleService appLifecycleService;
  final LocalNotificationService localNotificationService;

  void applyRevoked({
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required String revokerNickname,
    required String sourceMessageSenderNickname,
  }) {
    service.updateState(
      MessageServiceReducer.applyRevoked(
        service.currentState,
        conversationId: conversationId,
        seq: seq,
        clientMsgId: clientMsgId,
        revokerNickname: revokerNickname,
        sourceMessageSenderNickname: sourceMessageSenderNickname,
      ),
    );
  }

  void applyReadReceipts(List<MessageReceipt> receipts) {
    service.updateState(
      MessageServiceReducer.applyReadReceipts(service.currentState, receipts),
    );
  }

  void applyDeleted(String conversationId, List<String> clientMsgIds) {
    service.updateState(
      MessageServiceReducer.applyDeleted(
        service.currentState,
        conversationId,
        clientMsgIds,
      ),
    );
  }

  void applySendFailed(String clientMsgId, String error) {
    appLog.w('[MsgSvc] sendFailed: clientMsgId=$clientMsgId error=$error');
    service.updateState(
      MessageServiceReducer.applySendFailed(service.currentState, clientMsgId),
    );
  }

  void applyUploadProgress(String clientMsgId, int progress) {
    service.updateState(
      MessageServiceReducer.applyUploadProgress(
        service.currentState,
        clientMsgId,
        progress,
      ),
    );
  }

  /// 事件驱动更新会话列表（对齐官方 Demo：直接用 ConversationChanged 携带的数据更新，不重载 DB）
  void applyConversationEvent(List<LocalConversation> incoming) {
    service.updateState(
      MessageServiceReducer.applyConversationEvent(
        service.currentState,
        incoming,
      ),
    );
  }

  /// 收到新消息事件时直接追加到对应会话列表（对齐 Go SDK OnRecvNewMessage 驱动 UI 更新）
  void appendIncomingMessage(String conversationId, MessageInfo message) {
    final chatMessage = messageFromMessageInfo(message);
    if (appLifecycleService.isBackground.value) {
      unawaited(
        localNotificationService.showMessageNotification(
          title: chatMessage.senderNickname.isNotEmpty
              ? message.senderNickname
              : '新消息',
          body: notificationText(chatMessage),
        ),
      );
    }
    service.updateState(
      MessageServiceReducer.appendIncomingMessage(
        service.currentState,
        conversationId,
        chatMessage,
      ),
    );
  }
}

String notificationText(ChatMessage message) {
  if (message.contentType == 101) {
    try {
      final decoded = jsonDecode(message.content);
      if (decoded is Map<String, dynamic> && decoded['content'] is String) {
        return decoded['content'] as String;
      }
    } catch (_) {}
  }
  return message.content;
}
