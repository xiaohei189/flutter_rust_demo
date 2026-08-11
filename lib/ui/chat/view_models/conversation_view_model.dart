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

  const ConversationListState({
    this.conversations = const [],
    this.isSyncing = false,
    this.syncProgress = 0,
    this.isLoading = false,
    this.error,
    this.previews = const {},
    this.timeTexts = const {},
  });

  ConversationListState copyWith({
    List<Conversation>? conversations,
    bool? isSyncing,
    int? syncProgress,
    bool? isLoading,
    String? error,
    Map<String, String>? previews,
    Map<String, String>? timeTexts,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      previews: previews ?? this.previews,
      timeTexts: timeTexts ?? this.timeTexts,
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
    ref.listen(messageServiceProvider, (_, next) {
      _syncState(next);
    });
    Future.microtask(() => _syncState(ref.read(messageServiceProvider)));
    return const ConversationListState();
  }

  void _syncState(MessageServiceState messageServiceState) {
    final previews = <String, String>{};
    final timeTexts = <String, String>{};
    for (final conversation in messageServiceState.conversations) {
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
    state = state.copyWith(
      conversations: messageServiceState.conversations,
      isSyncing: messageServiceState.isSyncingConversations,
      syncProgress: messageServiceState.syncProgress,
      previews: previews,
      timeTexts: timeTexts,
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
