import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/message_service.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import 'message_service_provider.dart';

/// 会话列表状态
class ConversationListState {
  final List<im_conv.LocalConversation> conversations;
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
    List<im_conv.LocalConversation>? conversations,
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
  List<im_conv.LocalConversation> get pinnedConversations {
    return conversations.where((c) => c.isPinned).toList();
  }

  /// 获取未置顶会话列表
  List<im_conv.LocalConversation> get unpinnedConversations {
    return conversations.where((c) => !c.isPinned).toList();
  }

  /// 获取未读消息总数
  int get totalUnreadCount {
    return conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }
}

/// 会话列表 Notifier
class ConversationListNotifier extends StateNotifier<ConversationListState> {
  ConversationListNotifier(this._messageService)
      : super(const ConversationListState()) {
    _init();
  }

  final MessageService _messageService;

  void _init() {
    _messageService.addListener(_onServiceChanged);
    _syncState();
  }

  void _onServiceChanged() {
    _syncState();
  }

  void _syncState() {
    state = state.copyWith(
      conversations: _messageService.conversations,
      isSyncing: _messageService.isSyncingConversations,
      syncProgress: _messageService.syncProgress,
    );
  }

  /// 刷新会话列表
  Future<void> refreshConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 调用 MessageService 的方法刷新会话
      await _messageService.refreshConversations();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '刷新会话列表失败: $e',
      );
    }
  }

  /// 获取指定会话
  im_conv.LocalConversation? getConversation(String conversationId) {
    try {
      return state.conversations.firstWhere(
        (c) => c.conversationId == conversationId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _messageService.removeListener(_onServiceChanged);
    super.dispose();
  }
}

/// 会话列表 Provider
final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  return ConversationListNotifier(ref.read(messageServiceProvider));
});

/// 当前会话列表 Provider（便捷访问）
final conversationsProvider = Provider<List<im_conv.LocalConversation>>((ref) {
  return ref.watch(conversationListProvider).conversations;
});

/// 指定会话 Provider（按 ID）
final conversationByIdProvider = Provider.family<im_conv.LocalConversation?, String>((ref, id) {
  final conversations = ref.watch(conversationsProvider);
  try {
    return conversations.firstWhere((c) => c.conversationId == id);
  } catch (_) {
    return null;
  }
});

/// 未读消息总数 Provider
final totalUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(conversationListProvider).totalUnreadCount;
});
