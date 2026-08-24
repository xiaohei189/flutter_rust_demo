import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../../domain/models/conversation.dart';
import '../../../domain/models/conversation_flags.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/conversation_folder_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/message_service_provider.dart';
import '../widgets/list/group_filter_panel.dart' show GroupFilter;

/// 会话列表页状态
class ChatListState {
  final GroupFilter activeFilter;

  /// 激活的自定义分组名（null 表示未选择分组）。
  final String? activeFolder;

  const ChatListState({this.activeFilter = GroupFilter.all, this.activeFolder});

  ChatListState copyWith({GroupFilter? activeFilter, String? activeFolder}) {
    return ChatListState(
      activeFilter: activeFilter ?? this.activeFilter,
      // activeFolder 直接赋值：null 表示清除分组筛选。
      activeFolder: activeFolder,
    );
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
    if (state.activeFilter == filter && state.activeFolder == null) return;
    state = state.copyWith(activeFilter: filter, activeFolder: null);
  }

  /// 选择自定义分组（null 清除分组筛选）。
  void setFolder(String? folder) {
    if (state.activeFolder == folder) return;
    state = state.copyWith(activeFolder: folder);
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

  // ==================== ex 标记（flagged/done/unread/archived）====================
  // 编解码逻辑统一在领域模型 ConversationFlags，此处仅做转发。

  static bool isFlagged(Conversation conversation) =>
      ConversationFlags.fromConversation(conversation).flagged;

  static bool isDone(Conversation conversation) =>
      ConversationFlags.fromConversation(conversation).done;

  /// 是否被本地标记为未读（微信「标为未读」语义，仅本地生效）。
  static bool isMarkedUnread(Conversation conversation) =>
      ConversationFlags.fromConversation(conversation).markedUnread;

  /// 是否已归档（从普通列表隐藏，可在「归档」筛选中恢复）。
  static bool isArchived(Conversation conversation) =>
      ConversationFlags.fromConversation(conversation).archived;

  /// 展示用未读数：本地标未读时至少显示 1。
  static int effectiveUnreadCount(Conversation conversation) =>
      ConversationFlags.fromConversation(conversation)
          .effectiveUnreadCount(conversation);

  /// 合并更新 ex 中的标记，保留其他 key。
  static String updateFlags(
    Conversation conversation, {
    bool? flagged,
    bool? done,
    bool? unread,
    bool? archived,
  }) {
    final flags = ConversationFlags.fromConversation(conversation);
    return flags
        .copyWith(
          flagged: flagged,
          done: done,
          markedUnread: unread,
          archived: archived,
        )
        .encodeMerged(conversation.ex);
  }

  static String flagsEx({required bool flagged, required bool done}) =>
      ConversationFlags(flagged: flagged, done: done).encodeMerged('');

  int atMeCount(List<Conversation> conversations) =>
      conversations.where(isAtMeConversation).length;

  int flaggedCount(List<Conversation> conversations) =>
      conversations.where(isFlagged).length;

  int doneCount(List<Conversation> conversations) =>
      conversations.where(isDone).length;

  int archivedCount(List<Conversation> conversations) =>
      conversations.where(isArchived).length;

  List<Conversation> filteredConversations(List<Conversation> conversations) {
    final folder = state.activeFolder;
    if (folder != null) {
      final folders = ref.read(conversationFoldersProvider);
      final memberIds = folders[folder] ?? const <String>[];
      return conversations
          .where((c) => !isArchived(c) && memberIds.contains(c.conversationId))
          .toList();
    }
    final visible = state.activeFilter == GroupFilter.archived
        ? conversations.where(isArchived).toList()
        : conversations.where((c) => !isArchived(c)).toList();
    switch (state.activeFilter) {
      case GroupFilter.unread:
        return visible.where((c) => effectiveUnreadCount(c) > 0).toList();
      case GroupFilter.singleChat:
        return visible.where((c) => c.conversationType == 1).toList();
      case GroupFilter.groupChat:
        return visible
            .where((c) => c.conversationType == 2 || c.conversationType == 3)
            .toList();
      case GroupFilter.atMe:
        return visible.where(isAtMeConversation).toList();
      case GroupFilter.flagged:
        return visible.where(isFlagged).toList();
      case GroupFilter.done:
        return visible.where(isDone).toList();
      case GroupFilter.archived:
        return visible;
      case GroupFilter.all:
        return visible;
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
      GroupFilter.archived => '归档',
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
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: updateFlags(conversation, flagged: flagged),
        );
    await refreshConversations();
  }

  Future<void> toggleConversationDone(String conversationId, bool done) async {
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: updateFlags(conversation, done: done),
        );
    await refreshConversations();
  }

  /// 标为未读（本地标记，微信「标为未读」语义）。
  Future<void> markConversationAsUnread(String conversationId) async {
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: updateFlags(conversation, unread: true),
        );
    await refreshConversations();
  }

  /// 标为已读：清除本地未读标记并同步服务端已读。
  Future<void> markConversationAsRead(String conversationId) async {
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: updateFlags(conversation, unread: false),
        );
    await markConversationMessageAsRead(conversationId);
    await refreshConversations();
  }

  /// 归档会话：从普通列表隐藏，可在「归档」筛选中恢复。
  Future<void> archiveConversation(String conversationId) async {
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: updateFlags(conversation, archived: true),
        );
    await refreshConversations();
  }

  Future<void> unarchiveConversation(String conversationId) async {
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    await ref
        .read(messageRepositoryProvider)
        .setConversation(
          conversationId: conversationId,
          ex: updateFlags(conversation, archived: false),
        );
    await refreshConversations();
  }

  /// 全部归档（替代原「隐藏全部会话」）。
  Future<void> archiveAllConversations() async {
    final conversations = ref.read(conversationListProvider).conversations;
    final repository = ref.read(messageRepositoryProvider);
    for (final conversation in conversations) {
      if (isArchived(conversation)) continue;
      await repository.setConversation(
        conversationId: conversation.conversationId,
        ex: updateFlags(conversation, archived: true),
      );
    }
    await refreshConversations();
  }

  // ==================== 批量操作 ====================

  Future<void> batchTogglePin(
    Iterable<String> conversationIds,
    bool pinned,
  ) async {
    final repository = ref.read(messageRepositoryProvider);
    for (final id in conversationIds) {
      await repository.setConversationPinned(
        conversationId: id,
        isPinned: pinned,
      );
    }
    await refreshConversations();
  }

  Future<void> batchMarkRead(Iterable<String> conversationIds) async {
    for (final id in conversationIds) {
      final conversation = _getConversation(id);
      if (conversation != null) {
        await ref
            .read(messageRepositoryProvider)
            .setConversation(
              conversationId: id,
              ex: updateFlags(conversation, unread: false),
            );
      }
      await markConversationMessageAsRead(id);
    }
    await refreshConversations();
  }

  Future<void> batchArchive(Iterable<String> conversationIds) async {
    final repository = ref.read(messageRepositoryProvider);
    for (final id in conversationIds) {
      final conversation = _getConversation(id);
      if (conversation != null) {
        await repository.setConversation(
          conversationId: id,
          ex: updateFlags(conversation, archived: true),
        );
      }
    }
    await refreshConversations();
  }

  Future<void> batchDelete(Iterable<String> conversationIds) async {
    for (final id in conversationIds) {
      await deleteConversation(id);
    }
    await refreshConversations();
  }

  /// 重试最近一条发送失败的消息（列表预览「发送失败，点击重试」）。
  Future<void> retryFailedSend(String conversationId) async {
    final conversation = _getConversation(conversationId);
    if (conversation == null) return;
    final messages =
        ref.read(messageServiceProvider).messages[conversationId] ?? const [];
    ChatMessage? failed;
    for (final message in messages.reversed) {
      if (message.status == 3) {
        failed = message;
        break;
      }
    }
    if (failed == null) return;
    final sourceId = conversation.conversationType == 1
        ? conversation.userId
        : conversation.groupId;
    final sessionType = switch (conversation.conversationType) {
      1 => ChatSessionType.singleChat,
      2 => ChatSessionType.writeGroupChat,
      3 => ChatSessionType.readGroupChat,
      _ => ChatSessionType.notificationChat,
    };
    try {
      await ref
          .read(messageServiceProvider.notifier)
          .resendMessage(
            message: failed,
            sourceId: sourceId,
            sessionType: sessionType,
          );
      ref
          .read(messageServiceProvider.notifier)
          .removeMessage(conversationId, failed.clientMsgId);
      await refreshConversations();
    } catch (_) {
      // 重试失败保留失败状态，下次再试。
    }
  }

  Conversation? _getConversation(String conversationId) {
    return ref
        .read(conversationListProvider.notifier)
        .getConversation(conversationId);
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
