import 'dart:convert';

import '../../../data/mappers/conversation_mapper.dart';
import '../../../domain/models/conversation.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../generated/rust/event/events/message.dart' show MessageReceipt;
import '../../../domain/models/group_read_receipt.dart' show GroupReadReceipt;
import '../../../generated/rust/model/local.dart' show LocalConversation;

import 'message_service_state.dart';

/// 消息与会话状态变更的纯函数集合。
class MessageServiceReducer {
  static MessageServiceState appendIncomingMessage(
    MessageServiceState state,
    String conversationId,
    ChatMessage message,
  ) {
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    final exists = list.any((m) => m.clientMsgId == message.clientMsgId);
    if (!exists) {
      list.add(message);
    }
    newMessages[conversationId] = List<ChatMessage>.from(list);
    return state.copyWith(messages: newMessages);
  }

  static MessageServiceState applyGroupReadReceipts(
    MessageServiceState state,
    List<GroupReadReceipt> receipts,
  ) {
    if (receipts.isEmpty) return state;
    final updated = Map<String, GroupReadReceipt>.from(state.groupReadReceipts);
    for (final receipt in receipts) {
      updated[receipt.msgId] = receipt;
    }
    return state.copyWith(
      groupReadReceipts: updated,
      groupRevision: state.groupRevision + 1,
    );
  }

  static MessageServiceState applyRevoked(
    MessageServiceState state, {
    required String conversationId,
    required int seq,
    required String clientMsgId,
    required String revokerNickname,
    required String sourceMessageSenderNickname,
  }) {
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    final list = newMessages[conversationId];
    if (list == null || list.isEmpty) return state;

    final nickname = revokerNickname.isNotEmpty
        ? revokerNickname
        : sourceMessageSenderNickname;
    final revokedContent = jsonEncode({
      'content': '${nickname.isEmpty ? '对方' : nickname} 撤回了一条消息',
      'revokerNickname': nickname,
    });
    final idx = list.indexWhere(
      (m) => m.clientMsgId == clientMsgId || m.seq.toInt() == seq,
    );
    if (idx >= 0) {
      final updated = List<ChatMessage>.from(list);
      updated[idx] = updated[idx].copyWith(
        content: revokedContent,
        contentType: 2101,
        status: 4,
      );
      newMessages[conversationId] = updated;
      return state.copyWith(messages: newMessages);
    }
    return state;
  }

  static MessageServiceState applyReadReceipts(
    MessageServiceState state,
    List<MessageReceipt> receipts,
  ) {
    final msgIds = receipts.expand((r) => r.msgIds).toSet();
    if (msgIds.isEmpty) return state;

    final newMessages = <String, List<ChatMessage>>{};
    var changed = false;
    for (final entry in state.messages.entries) {
      final list = entry.value;
      if (!list.any((m) => msgIds.contains(m.clientMsgId))) {
        newMessages[entry.key] = list;
        continue;
      }
      newMessages[entry.key] = list
          .map(
            (m) => msgIds.contains(m.clientMsgId)
                ? m.copyWith(isRead: true)
                : m,
          )
          .toList();
      changed = true;
    }
    return changed ? state.copyWith(messages: newMessages) : state;
  }

  static MessageServiceState applyDeleted(
    MessageServiceState state,
    String conversationId,
    List<String> clientMsgIds,
  ) {
    final ids = clientMsgIds.toSet();
    final current = state.messages[conversationId];
    if (current == null || ids.isEmpty) return state;
    final updated = current.where((m) => !ids.contains(m.clientMsgId)).toList();
    if (updated.length == current.length) return state;
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    newMessages[conversationId] = updated;
    return state.copyWith(messages: newMessages);
  }

  static MessageServiceState applySendFailed(
    MessageServiceState state,
    String clientMsgId,
  ) {
    final newMessages = <String, List<ChatMessage>>{};
    var changed = false;
    for (final entry in state.messages.entries) {
      final list = entry.value;
      final idx = list.indexWhere((m) => m.clientMsgId == clientMsgId);
      if (idx < 0) {
        newMessages[entry.key] = list;
        continue;
      }
      final updated = List<ChatMessage>.from(list);
      updated[idx] = updated[idx].copyWith(status: 3);
      newMessages[entry.key] = updated;
      changed = true;
    }
    if (!changed) return state;
    final progress = Map<String, int>.from(state.uploadProgress)
      ..remove(clientMsgId);
    return state.copyWith(messages: newMessages, uploadProgress: progress);
  }

  static MessageServiceState applyUploadProgress(
    MessageServiceState state,
    String clientMsgId,
    int progress,
  ) {
    final nextProgress = progress.clamp(0, 100);
    final uploadProgress = Map<String, int>.from(state.uploadProgress);
    if (nextProgress >= 100) {
      uploadProgress.remove(clientMsgId);
    } else {
      uploadProgress[clientMsgId] = nextProgress;
    }
    return state.copyWith(uploadProgress: uploadProgress);
  }

  /// 会话排序时间：草稿时间优先于最新消息时间（对齐微信「草稿置顶」）。
  static int _conversationSortTime(Conversation c) {
    final draft = c.draftTextTime;
    final msg = c.latestMsgSendTime;
    return draft > msg ? draft : msg;
  }

  static MessageServiceState applyConversationEvent(
    MessageServiceState state,
    List<LocalConversation> incoming,
  ) {
    if (incoming.isEmpty) return state;
    final newConversations = List<Conversation>.from(state.conversations);
    for (final raw in incoming) {
      final conv = ConversationMapper.fromLocalConversation(raw);
      final index = newConversations.indexWhere(
        (c) => c.conversationId == conv.conversationId,
      );
      if (index >= 0) {
        final existing = newConversations[index];
        final existingTime = existing.latestMsgSendTime;
        final convTime = conv.latestMsgSendTime;
        final useExisting =
            existing.latestMsg.isNotEmpty && existingTime >= convTime;
        newConversations[index] = existing.copyWith(
          showName: conv.showName.isNotEmpty
              ? conv.showName
              : existing.showName,
          faceUrl: conv.faceUrl.isNotEmpty ? conv.faceUrl : existing.faceUrl,
          latestMsg: useExisting ? existing.latestMsg : conv.latestMsg,
          latestMsgSendTime: useExisting
              ? existing.latestMsgSendTime
              : conv.latestMsgSendTime,
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
          draftText: existing.draftText.isNotEmpty
              ? existing.draftText
              : conv.draftText,
          draftTextTime: existing.draftTextTime > 0
              ? existing.draftTextTime
              : conv.draftTextTime,
          maxSeq: conv.maxSeq,
          minSeq: conv.minSeq,
          isMsgDestruct: conv.isMsgDestruct,
          msgDestructTime: conv.msgDestructTime,
        );
      } else {
        newConversations.add(conv);
      }
    }
    newConversations.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return _conversationSortTime(b).compareTo(_conversationSortTime(a));
    });
    return state.copyWith(conversations: newConversations);
  }

  static MessageServiceState removeMessage(
    MessageServiceState state,
    String conversationId,
    String clientMsgId,
  ) {
    final current = state.messages[conversationId];
    if (current == null) return state;
    final updated = current.where((m) => m.clientMsgId != clientMsgId).toList();
    if (updated.length == current.length) return state;
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    newMessages[conversationId] = updated;
    return state.copyWith(messages: newMessages);
  }
}
