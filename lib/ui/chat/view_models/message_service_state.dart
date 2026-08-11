import '../../../domain/models/conversation.dart';
import '../../../generated/rust/event/events/message.dart'
    show GroupReadReceipt;
import '../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../generated/rust/model/user.dart' show UserInfo;

/// MessageService 的状态类
class MessageServiceState {
  final bool isConnected;
  final bool isSyncingConversations;
  final int syncProgress;
  final String currentUserId;
  final List<Conversation> conversations;
  final Map<String, List<MessageInfo>> messages;
  final Map<String, UserInfo> userProfiles;
  final UserInfo? loginUserProfile;
  final bool isInitializing;
  final int totalUnreadCount;
  final int friendRevision;
  final int groupRevision;

  /// 各会话当前正在输入的用户（conversationId -> userId）
  final Map<String, String> typingUsers;

  /// 各消息上传进度（clientMsgId -> 0-100）
  final Map<String, int> uploadProgress;

  /// 群聊已读统计（msgId -> 回执）
  final Map<String, GroupReadReceipt> groupReadReceipts;

  const MessageServiceState({
    this.isConnected = false,
    this.isSyncingConversations = false,
    this.syncProgress = 0,
    this.currentUserId = '',
    this.conversations = const [],
    this.messages = const {},
    this.userProfiles = const {},
    this.loginUserProfile,
    this.isInitializing = false,
    this.totalUnreadCount = 0,
    this.friendRevision = 0,
    this.groupRevision = 0,
    this.typingUsers = const {},
    this.uploadProgress = const {},
    this.groupReadReceipts = const {},
  });

  MessageServiceState copyWith({
    bool? isConnected,
    bool? isSyncingConversations,
    int? syncProgress,
    String? currentUserId,
    List<Conversation>? conversations,
    Map<String, List<MessageInfo>>? messages,
    Map<String, UserInfo>? userProfiles,
    UserInfo? loginUserProfile,
    bool? isInitializing,
    int? totalUnreadCount,
    int? friendRevision,
    int? groupRevision,
    Map<String, String>? typingUsers,
    Map<String, int>? uploadProgress,
    Map<String, GroupReadReceipt>? groupReadReceipts,
  }) {
    return MessageServiceState(
      isConnected: isConnected ?? this.isConnected,
      isSyncingConversations:
          isSyncingConversations ?? this.isSyncingConversations,
      syncProgress: syncProgress ?? this.syncProgress,
      currentUserId: currentUserId ?? this.currentUserId,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      userProfiles: userProfiles ?? this.userProfiles,
      loginUserProfile: loginUserProfile ?? this.loginUserProfile,
      isInitializing: isInitializing ?? this.isInitializing,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      friendRevision: friendRevision ?? this.friendRevision,
      groupRevision: groupRevision ?? this.groupRevision,
      typingUsers: typingUsers ?? this.typingUsers,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      groupReadReceipts: groupReadReceipts ?? this.groupReadReceipts,
    );
  }
}
