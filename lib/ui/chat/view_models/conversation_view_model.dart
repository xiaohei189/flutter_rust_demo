import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/message_service_provider.dart';
import '../../../src/rust/model/local.dart' show LocalConversation;
import 'message_service_notifier.dart';

/// 会话列表状态
class ConversationListState {
  final List<LocalConversation> conversations;
  final bool isSyncing;
  final int syncProgress;
  final bool isLoading;
  final String? error;

  const ConversationListState({
    this.conversations = const [],
    this.isSyncing = false,
    this.syncProgress = 0,
    this.isLoading = false,
    this.error,
  });

  ConversationListState copyWith({
    List<LocalConversation>? conversations,
    bool? isSyncing,
    int? syncProgress,
    bool? isLoading,
    String? error,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<LocalConversation> get pinnedConversations =>
      conversations.where((c) => c.isPinned).toList();

  List<LocalConversation> get unpinnedConversations =>
      conversations.where((c) => !c.isPinned).toList();

  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

/// 会话列表 ViewModel
class ConversationListNotifier extends StateNotifier<ConversationListState> {
  ConversationListNotifier(this._ref) : super(const ConversationListState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    _ref.listen(
      messageServiceProvider,
      (_, next) {
        _syncState(next);
      },
      fireImmediately: true,
    );
  }

  void _syncState(MessageServiceState messageServiceState) {
    state = state.copyWith(
      conversations: messageServiceState.conversations,
      isSyncing: messageServiceState.isSyncingConversations,
      syncProgress: messageServiceState.syncProgress,
    );
  }

  Future<void> refreshConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ref.read(messageServiceProvider.notifier).refreshConversations();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '刷新会话列表失败: $e');
    }
  }

  LocalConversation? getConversation(String conversationId) {
    try {
      return state.conversations.firstWhere(
        (c) => c.conversationId == conversationId,
      );
    } catch (_) {
      return null;
    }
  }
}
