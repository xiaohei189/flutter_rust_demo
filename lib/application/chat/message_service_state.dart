import '../../../domain/models/conversation.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/user_profile.dart' show UserProfile;
import '../../../domain/models/group_read_receipt.dart' show GroupReadReceipt;
import 'stores/connection_store.dart';
import 'stores/conversation_store.dart';
import 'stores/message_store.dart';
import 'stores/social_store.dart';
import 'stores/user_profile_store.dart';

/// MessageService 的组合状态：拆分为连接/会话/消息/用户资料/社交五个领域 Store。
class MessageServiceState {
  final ConnectionStore connection;
  final ConversationStore conversation;
  final MessageStore message;
  final UserProfileStore userProfile;
  final SocialStore social;

  MessageServiceState({
    bool? isConnected,
    bool? isSyncingConversations,
    int? syncProgress,
    String? currentUserId,
    List<Conversation>? conversations,
    Map<String, List<ChatMessage>>? messages,
    Map<String, UserProfile>? userProfiles,
    UserProfile? loginUserProfile,
    bool? isInitializing,
    int? totalUnreadCount,
    int? friendRevision,
    int? groupRevision,
    Map<String, String>? typingUsers,
    Map<String, int>? uploadProgress,
    Map<String, GroupReadReceipt>? groupReadReceipts,
  })  : connection = ConnectionStore(
          isConnected: isConnected ?? false,
          isInitializing: isInitializing ?? false,
        ),
        conversation = ConversationStore(
          conversations: conversations ?? const [],
          isSyncingConversations: isSyncingConversations ?? false,
          syncProgress: syncProgress ?? 0,
          totalUnreadCount: totalUnreadCount ?? 0,
        ),
        message = MessageStore(
          messages: messages ?? const {},
          typingUsers: typingUsers ?? const {},
          uploadProgress: uploadProgress ?? const {},
          groupReadReceipts: groupReadReceipts ?? const {},
        ),
        userProfile = UserProfileStore(
          currentUserId: currentUserId ?? '',
          userProfiles: userProfiles ?? const {},
          loginUserProfile: loginUserProfile,
        ),
        social = SocialStore(
          friendRevision: friendRevision ?? 0,
          groupRevision: groupRevision ?? 0,
        );

  bool get isConnected => connection.isConnected;
  bool get isSyncingConversations => conversation.isSyncingConversations;
  int get syncProgress => conversation.syncProgress;
  String get currentUserId => userProfile.currentUserId;
  List<Conversation> get conversations => conversation.conversations;
  Map<String, List<ChatMessage>> get messages => message.messages;
  Map<String, UserProfile> get userProfiles => userProfile.userProfiles;
  UserProfile? get loginUserProfile => userProfile.loginUserProfile;
  bool get isInitializing => connection.isInitializing;
  int get totalUnreadCount => conversation.totalUnreadCount;
  int get friendRevision => social.friendRevision;
  int get groupRevision => social.groupRevision;
  Map<String, String> get typingUsers => message.typingUsers;
  Map<String, int> get uploadProgress => message.uploadProgress;
  Map<String, GroupReadReceipt> get groupReadReceipts =>
      message.groupReadReceipts;

  MessageServiceState copyWith({
    bool? isConnected,
    bool? isSyncingConversations,
    int? syncProgress,
    String? currentUserId,
    List<Conversation>? conversations,
    Map<String, List<ChatMessage>>? messages,
    Map<String, UserProfile>? userProfiles,
    UserProfile? loginUserProfile,
    bool? isInitializing,
    int? totalUnreadCount,
    int? friendRevision,
    int? groupRevision,
    Map<String, String>? typingUsers,
    Map<String, int>? uploadProgress,
    Map<String, GroupReadReceipt>? groupReadReceipts,
  }) {
    return MessageServiceState(
      isConnected: isConnected ?? connection.isConnected,
      isInitializing: isInitializing ?? connection.isInitializing,
      isSyncingConversations:
          isSyncingConversations ?? conversation.isSyncingConversations,
      syncProgress: syncProgress ?? conversation.syncProgress,
      totalUnreadCount: totalUnreadCount ?? conversation.totalUnreadCount,
      currentUserId: currentUserId ?? userProfile.currentUserId,
      userProfiles: userProfiles ?? userProfile.userProfiles,
      loginUserProfile: loginUserProfile ?? userProfile.loginUserProfile,
      conversations: conversations ?? conversation.conversations,
      messages: messages ?? message.messages,
      typingUsers: typingUsers ?? message.typingUsers,
      uploadProgress: uploadProgress ?? message.uploadProgress,
      groupReadReceipts: groupReadReceipts ?? message.groupReadReceipts,
      friendRevision: friendRevision ?? social.friendRevision,
      groupRevision: groupRevision ?? social.groupRevision,
    );
  }
}