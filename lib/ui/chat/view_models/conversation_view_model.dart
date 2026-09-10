import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
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
    // 只依赖「失败会话集合键」而不是整个 messages：
    // 历史消息翻页/新消息会替换 messages Map 身份，若直接 watch 会在每次消息
    // 变化时重算全部会话的预览（每个会话一次 JSON 解析）与时间格式化。
    final failedConversationKey = ref.watch(
      messageServiceProvider.select(
        (s) => failedConversationIdsKeyOf(s.messages),
      ),
    );
    final previews = <String, String>{};
    final timeTexts = <String, String>{};
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
    return ConversationListState(
      conversations: conversations,
      isSyncing: isSyncing,
      syncProgress: syncProgress,
      previews: previews,
      timeTexts: timeTexts,
      typingByConversation: Map.unmodifiable(typingUsers),
      failedConversationIds: failedConversationKey.isEmpty
          ? const <String>{}
          : failedConversationKey.split(',').toSet(),
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

/// 计算「最近一条消息发送失败」的会话集合键（空集合返回空串）。
///
/// 返回值是可值比较的字符串，配合 `select` 使用：只有失败集合真正变化时
/// 才会让会话列表重建，消息加载/新消息不会触发全表重算。
/// 会话 ID 形如 `si_<uid>_<uid>` / `g_<gid>` / `sg_<gid>`，不含逗号。
String failedConversationIdsKeyOf(Map<String, List<ChatMessage>> messages) {
  List<String>? failed;
  for (final entry in messages.entries) {
    final list = entry.value;
    // status == 3 表示发送失败（MessageSendStatus.sendFailed）。
    if (list.isNotEmpty && list.last.status == 3) {
      (failed ??= <String>[]).add(entry.key);
    }
  }
  if (failed == null) return '';
  if (failed.length > 1) failed.sort();
  return failed.join(',');
}
