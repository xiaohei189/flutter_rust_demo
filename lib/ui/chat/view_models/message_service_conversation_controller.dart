import 'dart:async';

import '../../../domain/models/conversation.dart';
import '../../../generated/rust/constant/enums.dart' show SessionType;
import '../../../generated/rust/event/events/conversation.dart';
import '../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../ui/core/extensions/conversation_extensions.dart';
import '../../core/utils/app_logger.dart';
import 'message_service_notifier.dart';

/// 会话事件、加载、草稿、已读、置顶、删除与会话管理。
class MessageServiceConversationController {
  MessageServiceConversationController(this.service);

  final MessageServiceNotifier service;

  bool _loadingConversations = false;
  bool _reloadConversationsPending = false;

  void handleEvent(ConversationEvent event) {
    event.maybeWhen(
      syncStarted: (_) => service.updateState(
        service.currentState.copyWith(
          isSyncingConversations: true,
          syncProgress: 0,
        ),
      ),
      syncFinished: (_) {
        service.updateState(
          service.currentState.copyWith(
            isSyncingConversations: false,
            syncProgress: 100,
          ),
        );
        unawaited(loadConversations());
      },
      syncProgress: (p, _) => service.updateState(
        service.currentState.copyWith(
          isSyncingConversations: true,
          syncProgress: p,
        ),
      ),
      totalUnreadCountChanged: (c) {
        appLog.i('[MsgSvc] totalUnreadCountChanged: $c');
        service.updateState(service.currentState.copyWith(totalUnreadCount: c));
      },
      changed: (conversations) {
        appLog.i('[MsgSvc] conversationChanged: count=${conversations.length}');
        service.applyConversationEvent(conversations);
      },
      new_: (conversations) {
        appLog.i('[MsgSvc] newConversation: count=${conversations.length}');
        service.applyConversationEvent(conversations);
      },
      deleted: (_) => appLog.i('[MsgSvc] conversationDeleted'),
      userInputStatusChanged: (cid, uid, platformIds) {
        appLog.i(
          '[MsgSvc] typing: conv=$cid user=$uid platforms=${platformIds.length}',
        );
        final typingUsers = Map<String, String>.from(
          service.currentState.typingUsers,
        );
        if (platformIds.isNotEmpty) {
          typingUsers[cid] = uid;
        } else {
          typingUsers.remove(cid);
        }
        service.updateState(
          service.currentState.copyWith(typingUsers: typingUsers),
        );
      },
      syncFailed: (reinstalled, e) =>
          appLog.i('[MsgSvc] syncFailed: reinstalled=$reinstalled error=$e'),
      orElse: () {},
    );
  }

  Future<void> loadConversations() async {
    if (service.client == null) {
      appLog.w('[MessageService] _loadConversations 跳过：client 为空');
      return;
    }
    if (_loadingConversations) {
      _reloadConversationsPending = true;
      return;
    }
    _loadingConversations = true;

    try {
      final conversations = await service.repository.getConversations();
      final newConversations = List<Conversation>.from(
        service.currentState.conversations,
      );
      final dbIds = conversations.map((c) => c.conversationId).toSet();
      newConversations.removeWhere((c) => !dbIds.contains(c.conversationId));
      final seenIds = <String>{};
      newConversations.removeWhere((c) => !seenIds.add(c.conversationId));
      for (final conv in conversations) {
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
        final aTime = a.latestMsgSendTime;
        final bTime = b.latestMsgSendTime;
        return bTime.compareTo(aTime);
      });
      service.updateState(
        service.currentState.copyWith(conversations: newConversations),
      );
      final userIds = conversations
          .where((c) => c.userId.isNotEmpty)
          .map((c) => c.userId)
          .toSet()
          .toList();
      unawaited(service.preloadUserProfiles(userIds));
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载会话列表失败: $e');
    } finally {
      _loadingConversations = false;
      if (_reloadConversationsPending) {
        _reloadConversationsPending = false;
        unawaited(loadConversations());
      }
    }
  }

  Future<void> refreshConversations() async {
    await loadConversations();
  }

  void removeConversation(String conversationId) {
    final newConversations = List<Conversation>.from(
      service.currentState.conversations,
    );
    newConversations.removeWhere((c) => c.conversationId == conversationId);
    final newMessages = Map<String, List<MessageInfo>>.from(
      service.currentState.messages,
    );
    newMessages.remove(conversationId);
    service.updateState(
      service.currentState.copyWith(
        conversations: newConversations,
        messages: newMessages,
      ),
    );
  }

  Future<void> markConversationMessageAsRead(String conversationId) async {
    if (service.client == null) return;
    try {
      final conv = service.currentState.conversations
          .where((c) => c.conversationId == conversationId)
          .firstOrNull;
      final sessionType = conv?.sessionType ?? SessionType.singleChat;
      appLog.i('[READ] Service 标记已读: sessionType=$sessionType');
      await service.repository.markConversationMessageAsRead(
        conversationId: conversationId,
        sessionType: sessionType,
      );
      final newConversations = List<Conversation>.from(
        service.currentState.conversations,
      );
      final idx = newConversations.indexWhere(
        (c) => c.conversationId == conversationId,
      );
      if (idx >= 0) {
        newConversations[idx] = newConversations[idx].copyWith(unreadCount: 0);
      }
      service.updateState(
        service.currentState.copyWith(conversations: newConversations),
      );
    } catch (e) {
      appLog.e('[READ] 标记已读失败: $e');
    }
  }

  Future<void> saveDraft(String conversationId, String draftText) async {
    if (service.client == null) return;
    try {
      final newConversations = List<Conversation>.from(
        service.currentState.conversations,
      );
      final idx = newConversations.indexWhere(
        (c) => c.conversationId == conversationId,
      );
      if (idx >= 0) {
        final conv = newConversations[idx];
        final now = DateTime.now().millisecondsSinceEpoch;
        newConversations[idx] = conv.copyWith(
          draftText: draftText,
          draftTextTime: now,
        );
        final next = service.currentState.copyWith(
          conversations: newConversations,
        );
        unawaited(Future<void>.microtask(() => service.updateState(next)));
      }
      await service.repository.setConversationDraft(
        conversationId: conversationId,
        draftText: draftText,
      );
    } catch (e) {
      appLog.e('[MessageService] 保存草稿失败: $e');
    }
  }

  Future<void> clearDraft(String conversationId) async {
    if (service.client == null) return;
    try {
      final newConversations = List<Conversation>.from(
        service.currentState.conversations,
      );
      final idx = newConversations.indexWhere(
        (c) => c.conversationId == conversationId,
      );
      if (idx >= 0) {
        newConversations[idx] = newConversations[idx].copyWith(
          draftText: '',
          draftTextTime: 0,
        );
        final next = service.currentState.copyWith(
          conversations: newConversations,
        );
        unawaited(Future<void>.microtask(() => service.updateState(next)));
      }
      await service.repository.clearConversationDraft(
        conversationId: conversationId,
      );
    } catch (e) {
      appLog.e('[MessageService] 清除草稿失败: $e');
    }
  }

  Future<void> toggleConversationPin(
    String conversationId,
    bool isPinned,
  ) async {
    if (service.client == null) return;
    try {
      await service.repository.setConversationPinned(
        conversationId: conversationId,
        isPinned: isPinned,
      );
      await loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 切换置顶失败: $e');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    if (service.client == null) return;
    try {
      await service.repository.deleteConversation(
        conversationId: conversationId,
      );
      await loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 删除会话失败: $e');
    }
  }

  Future<void> hideConversation(String conversationId) async {
    if (service.client == null) return;
    try {
      await service.repository.hideConversation(conversationId: conversationId);
      await loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 隐藏会话失败: $e');
    }
  }

  Future<void> markAllConversationsAsRead() async {
    if (service.client == null) return;
    try {
      await service.repository.markAllConversationsAsRead();
      await loadConversations();
    } catch (e) {
      appLog.e('[MessageService] 标记全部已读失败: $e');
    }
  }
}
