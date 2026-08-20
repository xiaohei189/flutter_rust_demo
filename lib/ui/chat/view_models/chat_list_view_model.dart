import 'dart:convert';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/message_service_provider.dart';
import '../widgets/list/group_filter_panel.dart' show GroupFilter;

/// 会话列表页状态
class ChatListState {
  final GroupFilter activeFilter;

  const ChatListState({this.activeFilter = GroupFilter.all});

  ChatListState copyWith({GroupFilter? activeFilter}) {
    return ChatListState(activeFilter: activeFilter ?? this.activeFilter);
  }
}

/// 会话列表 ViewModel：负责筛选、空列表兜底刷新与会话操作。
class ChatListViewModel extends Notifier<ChatListState> {
  Timer? _delayRefreshTimer;

  @override
  ChatListState build() {
    ref.onDispose(() => _delayRefreshTimer?.cancel());
    Future.microtask(_scheduleEmptyRefresh);
    return const ChatListState();
  }

  void _scheduleEmptyRefresh() {
    _delayRefreshTimer = Timer(const Duration(seconds: 3), () {
      if (ref.read(conversationListProvider).conversations.isEmpty) {
        ref.read(conversationListProvider.notifier).refreshConversations();
      }
    });
  }

  void setFilter(GroupFilter filter) {
    if (state.activeFilter == filter) return;
    state = state.copyWith(activeFilter: filter);
  }

  bool isQuickTab(GroupFilter filter) =>
      filter == GroupFilter.all ||
      filter == GroupFilter.unread ||
      filter == GroupFilter.flagged;

  int groupChatCount(List<Conversation> conversations) => conversations
      .where((c) => c.conversationType == 2 || c.conversationType == 3)
      .length;

  static bool isAtMeConversation(Conversation conversation) =>
      conversation.groupAtType == 1 || conversation.groupAtType == 3;

  static bool _flagValue(Conversation conversation, String key) {
    if (conversation.ex.isEmpty) return false;
    try {
      final map = jsonDecode(conversation.ex) as Map<String, dynamic>;
      return map[key] == true;
    } catch (_) {
      return false;
    }
  }

  static bool isFlagged(Conversation conversation) =>
      _flagValue(conversation, 'flagged');

  static bool isDone(Conversation conversation) =>
      _flagValue(conversation, 'done');

  static String flagsEx({required bool flagged, required bool done}) =>
      jsonEncode({'flagged': flagged, 'done': done});

  int atMeCount(List<Conversation> conversations) =>
      conversations.where(isAtMeConversation).length;

  int flaggedCount(List<Conversation> conversations) =>
      conversations.where(isFlagged).length;

  int doneCount(List<Conversation> conversations) =>
      conversations.where(isDone).length;

  List<Conversation> filteredConversations(List<Conversation> conversations) {
    switch (state.activeFilter) {
      case GroupFilter.unread:
        return conversations.where((c) => c.unreadCount > 0).toList();
      case GroupFilter.singleChat:
        return conversations.where((c) => c.conversationType == 1).toList();
      case GroupFilter.groupChat:
        return conversations
            .where((c) => c.conversationType == 2 || c.conversationType == 3)
            .toList();
      case GroupFilter.atMe:
        return conversations.where(isAtMeConversation).toList();
      case GroupFilter.flagged:
        return conversations.where(isFlagged).toList();
      case GroupFilter.done:
        return conversations.where(isDone).toList();
      case GroupFilter.all:
        return conversations;
    }
  }

  String emptyStateLabel(GroupFilter filter) {
    return switch (filter) {
      GroupFilter.all => '消息',
      GroupFilter.unread => '未读',
      GroupFilter.flagged => '标记',
      GroupFilter.atMe => '@我',
      GroupFilter.singleChat => '单聊',
      GroupFilter.groupChat => '群组',
      GroupFilter.done => '已完成',
    };
  }

  String? get displayAvatarUrl =>
      ref.read(userProfileProvider.notifier).getDisplayAvatarUrl();

  Future<void> refreshConversations() {
    return ref.read(conversationListProvider.notifier).refreshConversations();
  }

  Future<void> deleteConversation(String conversationId) {
    return ref
        .read(messageServiceProvider.notifier)
        .deleteConversation(conversationId);
  }

  Future<void> toggleConversationPin(String conversationId, bool isPinned) {
    return ref
        .read(messageServiceProvider.notifier)
        .toggleConversationPin(conversationId, isPinned);
  }

  Future<void> markConversationMessageAsRead(String conversationId) {
    return ref
        .read(messageServiceProvider.notifier)
        .markConversationMessageAsRead(conversationId);
  }

  Future<void> toggleConversationMute(String conversationId, bool muted) async {
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          recvMsgOpt: muted ? 1 : 0,
        );
    await refreshConversations();
  }

  Future<void> clearConversation(String conversationId) async {
    await ref
        .read(messageRepositoryProvider)
        .clearConversationAndDeleteAllMsg(conversationId);
    await refreshConversations();
  }

  Future<void> toggleConversationFlagged(
    String conversationId,
    bool flagged,
  ) async {
    final conversation = ref
        .read(conversationListProvider.notifier)
        .getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: flagsEx(flagged: flagged, done: isDone(conversation)),
        );
    await refreshConversations();
  }

  Future<void> toggleConversationDone(String conversationId, bool done) async {
    final conversation = ref
        .read(conversationListProvider.notifier)
        .getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: flagsEx(flagged: isFlagged(conversation), done: done),
        );
    await refreshConversations();
  }

  Future<void> hideConversation(String conversationId) {
    return ref
        .read(messageServiceProvider.notifier)
        .hideConversation(conversationId);
  }

  Future<void> hideAllConversations() {
    return ref.read(messageServiceProvider.notifier).hideAllConversations();
  }
}
