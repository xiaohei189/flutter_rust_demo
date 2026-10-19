import '../../../../domain/models/conversation.dart';

class ConversationStore {
  final List<Conversation> conversations;
  final bool isSyncingConversations;
  final int syncProgress;
  final String? syncError;
  final int totalUnreadCount;

  const ConversationStore({
    this.conversations = const [],
    this.isSyncingConversations = false,
    this.syncProgress = 0,
    this.syncError,
    this.totalUnreadCount = 0,
  });

  ConversationStore copyWith({
    List<Conversation>? conversations,
    bool? isSyncingConversations,
    int? syncProgress,
    String? syncError,
    bool clearSyncError = false,
    int? totalUnreadCount,
  }) {
    if (conversations == null &&
        isSyncingConversations == null &&
        syncProgress == null &&
        syncError == null &&
        !clearSyncError &&
        totalUnreadCount == null) {
      return this;
    }
    return ConversationStore(
      conversations: conversations ?? this.conversations,
      isSyncingConversations:
          isSyncingConversations ?? this.isSyncingConversations,
      syncProgress: syncProgress ?? this.syncProgress,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }
}
