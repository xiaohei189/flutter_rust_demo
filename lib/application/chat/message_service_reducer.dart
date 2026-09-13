import 'dart:convert';

import '../../../data/mappers/conversation_mapper.dart';
import '../../../domain/models/conversation.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/message.dart' show MessageSendStatus;
import '../../../generated/rust/event/events/message.dart' show MessageReceipt;
import '../../../domain/models/group_read_receipt.dart' show GroupReadReceipt;
import '../../../generated/rust/model/local.dart' show LocalConversation;

import 'message_service_state.dart';

/// 僵尸「发送中」判定阈值（与 Rust `STALE_SENDING_RETRY_MS` 保持一致）。
///
/// 超过该时长仍未收到发送结果、且没有进行中的上传，即认为这条消息永远不会
/// 收到回执（进程被杀 / 网络黑洞），标记为失败让用户可以重发。
const int kStaleSendingTimeoutMs = 30000;

/// 消息与会话状态变更的纯函数集合。
class MessageServiceReducer {
  /// 发送状态收敛（幂等）：1=发送中 / 2=成功 / 3=失败。
  ///
  /// 发送中的乐观条、成功替换、失败标态（含 SDK sendFailed 事件）都走这里，
  /// 保证同一 clientMsgId 的状态只由一个入口改写，避免多来源双写差异。
  static MessageServiceState applySendStatus(
    MessageServiceState state,
    String conversationId,
    String clientMsgId,
    int status,
  ) {
    final list = state.messages[conversationId];
    if (list == null) return state;
    final index = list.indexWhere((m) => m.clientMsgId == clientMsgId);
    if (index < 0 || list[index].status == status) return state;

    final updated = List<ChatMessage>.from(list);
    updated[index] = updated[index].copyWith(status: status);
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    newMessages[conversationId] = updated;
    return state.copyWith(messages: newMessages);
  }

  /// 僵尸「发送中」兜底：进入会话/回到前台时，把本地超过 [timeoutMs] 仍停在
  /// 发送中、且没有进行中上传的条目标记为失败。
  ///
  /// 进程被杀或网络黑洞会让一条消息永远收不到回执；不兜底的话气泡会一直转圈，
  /// 也没有任何入口触发重发。阈值与 Rust 侧 `STALE_SENDING_RETRY_MS` 一致，
  /// 保证「标失败 → 点重发」在 SDK 侧同样被允许。
  static MessageServiceState sweepStaleSending(
    MessageServiceState state,
    String conversationId, {
    required int now,
    int timeoutMs = kStaleSendingTimeoutMs,
  }) {
    final list = state.messages[conversationId];
    if (list == null || list.isEmpty) return state;

    var changed = false;
    final updated = <ChatMessage>[];
    for (final message in list) {
      final isStale =
          message.status == MessageSendStatus.sending.value &&
          now - message.sendTime >= timeoutMs &&
          // 正在上传的消息（有进度）不算僵尸，等上传结束再判定
          !state.uploadProgress.containsKey(message.clientMsgId);
      if (isStale) changed = true;
      updated.add(
        isStale
            ? message.copyWith(status: MessageSendStatus.sendFailed.value)
            : message,
      );
    }
    if (!changed) return state;

    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    newMessages[conversationId] = updated;
    return state.copyWith(messages: newMessages);
  }

  /// 消息上屏统一入口（本地发送 / 服务端接收都走这里）。
  ///
  /// 同一 `clientMsgId` 已存在时就地覆盖：发送成功后的状态事件、服务端回显都靠它
  /// 收敛到同一条消息上，不会产生重复气泡。
  /// 事件可能乱序（「发送中」事件晚于成功事件到达），因此已处于终态的消息
  /// 不会被「发送中」改回。
  static MessageServiceState upsertIncomingMessage(
    MessageServiceState state,
    String conversationId,
    ChatMessage message,
  ) {
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    final list = newMessages[conversationId] ?? const <ChatMessage>[];
    final index = list.indexWhere((m) => m.clientMsgId == message.clientMsgId);

    var incoming = message;
    if (index >= 0 &&
        list[index].status != MessageSendStatus.sending.value &&
        message.status == MessageSendStatus.sending.value) {
      incoming = message.copyWith(status: list[index].status);
    }

    final updated = List<ChatMessage>.from(list);
    if (index >= 0) {
      updated[index] = incoming;
    } else {
      updated.add(incoming);
    }
    newMessages[conversationId] = updated;

    // 对方消息已到达 → 立即结束其「正在输入」状态（业界通行做法，避免提示挂住）
    final typingUsers = state.typingUsers;
    final typingUserId = typingUsers[conversationId];
    if (typingUserId != null && typingUserId == incoming.sendId) {
      final nextTypingUsers = Map<String, String>.from(typingUsers)
        ..remove(conversationId);
      return state.copyWith(
        messages: newMessages,
        typingUsers: nextTypingUsers,
      );
    }
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
            (m) =>
                msgIds.contains(m.clientMsgId) ? m.copyWith(isRead: true) : m,
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
