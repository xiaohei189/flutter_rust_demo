import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/message_service_notifier.dart';
import '../src/rust/domain/model/local.dart' show LocalConversation;
import 'message_service_provider.dart';

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

  /// 获取置顶会话列表
  List<LocalConversation> get pinnedConversations {
    return conversations.where((c) => c.isPinned == 1).toList();
  }

  /// 获取未置顶会话列表
  List<LocalConversation> get unpinnedConversations {
    return conversations.where((c) => c.isPinned == 0).toList();
  }

  /// 获取未读消息总数
  int get totalUnreadCount {
    return conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }
}

/// 会话列表 Notifier
class ConversationListNotifier extends StateNotifier<ConversationListState> {
  ConversationListNotifier(this._ref)
      : super(const ConversationListState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    // 监听 messageServiceProvider 的状态变化
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

  /// 刷新会话列表
  Future<void> refreshConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ref.read(messageServiceProvider.notifier).refreshConversations();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '刷新会话列表失败: $e',
      );
    }
  }

  /// 获取指定会话
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

/// 会话列表 Provider
final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  return ConversationListNotifier(ref);
});

/// 当前会话列表 Provider（便捷访问）
final conversationsProvider = Provider<List<LocalConversation>>((ref) {
  return ref.watch(conversationListProvider).conversations;
});

/// 指定会话 Provider（按 ID）
final conversationByIdProvider = Provider.family<LocalConversation?, String>((ref, id) {
  final conversations = ref.watch(conversationsProvider);
  try {
    return conversations.firstWhere((c) => c.conversationId == id);
  } catch (_) {
    return null;
  }
});

/// 未读消息总数 Provider
/// 直接读取 Rust 侧 TotalUnreadCountChanged 事件推送的权威值，不从会话列表累加
final totalUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(
    messageServiceProvider.select((s) => s.totalUnreadCount),
  );
});
