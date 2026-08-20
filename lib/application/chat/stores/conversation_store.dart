import '../../../../domain/models/conversation.dart';

class ConversationStore {
  final List<Conversation> conversations;
  final bool isSyncingConversations;
  final int syncProgress;
  final int totalUnreadCount;

  const ConversationStore({
    this.conversations = const [],
    this.isSyncingConversations = false,
    this.syncProgress = 0,
    this.totalUnreadCount = 0,
  });

  ConversationStore copyWith({
    List<Conversation>? conversations,
    bool? isSyncingConversations,
    int? syncProgress,
    int? totalUnreadCount,
  }) {
    return ConversationStore(
      conversations: conversations ?? this.conversations,
      isSyncingConversations:
          isSyncingConversations ?? this.isSyncingConversations,
      syncProgress: syncProgress ?? this.syncProgress,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }
}