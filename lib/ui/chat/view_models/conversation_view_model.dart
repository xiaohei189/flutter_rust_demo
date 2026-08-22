import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../providers/message_service_provider.dart';
import '../utils/conversation_display.dart';

/// 会话列表状态
class ConversationListState {
  final List<Conversation> conversations;
  final bool isSyncing;
  final int syncProgress;
  final bool isLoading;
  final String? error;
  final Map<String, String> previews;
  final Map<String, String> timeTexts;

  /// 正在输入的会话：conversationId -> 输入方 userId（空字符串表示未知）。
  final Map<String, String> typingByConversation;

  /// 最近一条消息发送失败的会话 ID 集合。
  final Set<String> failedConversationIds;

  const ConversationListState({
    this.conversations = const [],
    this.isSyncing = false,
    this.syncProgress = 0,
    this.isLoading = false,
    this.error,
    this.previews = const {},
    this.timeTexts = const {},
    this.typingByConversation = const {},
    this.failedConversationIds = const {},
  });

  ConversationListState copyWith({
    List<Conversation>? conversations,
    bool? isSyncing,
    int? syncProgress,
    bool? isLoading,
    String? error,
    Map<String, String>? previews,
    Map<String, String>? timeTexts,
    Map<String, String>? typingByConversation,
    Set<String>? failedConversationIds,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      previews: previews ?? this.previews,
      timeTexts: timeTexts ?? this.timeTexts,
      typingByConversation: typingByConversation ?? this.typingByConversation,
      failedConversationIds:
          failedConversationIds ?? this.failedConversationIds,
    );
  }

  List<Conversation> get pinnedConversations =>
      conversations.where((c) => c.isPinned).toList();

  List<Conversation> get unpinnedConversations =>
      conversations.where((c) => !c.isPinned).toList();

  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

/// 会话列表 ViewModel
class ConversationListNotifier extends Notifier<ConversationListState> {
  @override
  ConversationListState build() {
    final conversations = ref.watch(
      messageServiceProvider.select((s) => s.conversations),
    );
    final isSyncing = ref.watch(
      messageServiceProvider.select((s) => s.isSyncingConversations),
    );
    final syncProgress = ref.watch(
      messageServiceProvider.select((s) => s.syncProgress),
    );
    final typingUsers = ref.watch(
      messageServiceProvider.select((s) => s.typingUsers),
    );
    final messages = ref.watch(
      messageServiceProvider.select((s) => s.messages),
    );
    final previews = <String, String>{};
    final timeTexts = <String, String>{};
    final failedConversationIds = <String>{};
    for (final conversation in conversations) {
      previews[conversation.conversationId] = latestMessagePreview(
        conversation.latestMsg,
      );
      final displayTime =
          conversation.draftTextTime > conversation.latestMsgSendTime
          ? conversation.draftTextTime
          : conversation.latestMsgSendTime;
      timeTexts[conversation.conversationId] = formatConversationTime(
        displayTime,
      );
    }
    for (final entry in messages.entries) {
      final list = entry.value;
      // 最近一条消息发送失败（status == 3）时在列表中提示重试。
      if (list.isNotEmpty && list.last.status == 3) {
        failedConversationIds.add(entry.key);
      }
    }
    return ConversationListState(
      conversations: conversations,
      isSyncing: isSyncing,
      syncProgress: syncProgress,
      previews: previews,
      timeTexts: timeTexts,
      typingByConversation: Map.unmodifiable(typingUsers),
      failedConversationIds: failedConversationIds,
    );
  }

  Future<void> refreshConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(messageServiceProvider.notifier).refreshConversations();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '刷新会话列表失败: $e');
    }
  }

  Conversation? getConversation(String conversationId) {
    try {
      return state.conversations.firstWhere(
        (c) => c.conversationId == conversationId,
      );
    } catch (_) {
      return null;
    }
  }
}
