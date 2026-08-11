import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/user.dart';
import '../../contacts/providers/friend_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/message_service_provider.dart';

/// 聊天设置页状态
class ChatSettingsState {
  final bool initialized;
  final bool muteNotification;
  final bool pinChat;
  final bool privateChat;
  final String? error;

  const ChatSettingsState({
    this.initialized = false,
    this.muteNotification = false,
    this.pinChat = false,
    this.privateChat = false,
    this.error,
  });

  ChatSettingsState copyWith({
    bool? initialized,
    bool? muteNotification,
    bool? pinChat,
    bool? privateChat,
    String? error,
    bool clearError = false,
  }) {
    return ChatSettingsState(
      initialized: initialized ?? this.initialized,
      muteNotification: muteNotification ?? this.muteNotification,
      pinChat: pinChat ?? this.pinChat,
      privateChat: privateChat ?? this.privateChat,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 聊天设置 ViewModel：负责会话开关、清空、退出、群设置与邀请成员。
class ChatSettingsViewModel extends FamilyNotifier<ChatSettingsState, String> {
  @override
  ChatSettingsState build(String conversationId) {
    return const ChatSettingsState();
  }

  ChatSettingsState get currentState => state;

  Conversation? get _conversation {
    final newService = ref.read(conversationServiceProvider);
    final conversation = newService.getConversation(arg);
    if (conversation != null) return conversation;
    return ref
        .read(conversationListProvider)
        .conversations
        .where((c) => c.conversationId == arg)
        .firstOrNull;
  }

  Conversation? get conversation => _conversation;

  bool get isGroup {
    final conv = conversation;
    return conv?.conversationType == 2 || conv?.conversationType == 3;
  }

  String get groupId {
    final conversation = _conversation;
    if (conversation == null) return arg;
    return conversation.groupId.isNotEmpty ? conversation.groupId : arg;
  }

  String get displayName {
    final conversation = _conversation;
    if (conversation == null) return '未知';
    return conversation.showName.isNotEmpty
        ? conversation.showName
        : isGroup
        ? '群聊'
        : '用户';
  }

  User get chatUser {
    final conversation = _conversation;
    if (conversation == null) {
      return User(id: arg, name: '未知', avatar: null);
    }
    return User(
      id: conversation.userId.isNotEmpty ? conversation.userId : groupId,
      name: displayName,
      avatar: conversation.faceUrl.isNotEmpty ? conversation.faceUrl : null,
    );
  }

  void initialize(Conversation conversation) {
    if (state.initialized) return;
    state = state.copyWith(
      initialized: true,
      muteNotification: conversation.recvMsgOpt == 1,
      pinChat: conversation.isPinned,
      privateChat: conversation.isPrivateChat,
    );
  }

  Future<void> loadGroupMembers() {
    return ref.read(groupMemberProvider(groupId).notifier).loadMembers();
  }

  Future<void> loadInviteFriends() {
    return ref.read(friendListProvider.notifier).loadFriends();
  }

  Future<void> setMuteNotification(bool value) async {
    state = state.copyWith(muteNotification: value, clearError: true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .setConversation(conversationId: arg, recvMsgOpt: value ? 1 : 0);
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
    }
  }

  Future<void> setPinChat(bool value) async {
    state = state.copyWith(pinChat: value, clearError: true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .setConversationPinned(conversationId: arg, isPinned: value);
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
    }
  }

  Future<void> setPrivateChat(bool value) async {
    state = state.copyWith(privateChat: value, clearError: true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .setConversationPrivate(conversationId: arg, isPrivate: value);
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
    }
  }

  Future<bool> quitGroup() async {
    try {
      await ref.read(groupRepositoryProvider).quitGroup(groupId);
      return true;
    } catch (e) {
      state = state.copyWith(error: '退出群组失败: $e');
      return false;
    }
  }

  Future<bool> clearHistory() async {
    try {
      await ref
          .read(messageRepositoryProvider)
          .clearConversationAndDeleteAllMsg(arg);
      return true;
    } catch (e) {
      state = state.copyWith(error: '清空聊天记录失败: $e');
      return false;
    }
  }

  Future<bool> updateGroupNickname(String nickname) async {
    final currentUserId = ref.read(userProfileProvider).profile?.userId ?? '';
    if (currentUserId.isEmpty || nickname.isEmpty) return false;
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupMemberInfo(groupId, currentUserId, nickname: nickname);
      return true;
    } catch (e) {
      state = state.copyWith(error: '更新失败: $e');
      return false;
    }
  }

  Future<String> currentGroupAnnouncement() async {
    try {
      final groups = await ref.read(groupRepositoryProvider).getGroupsInfo([
        groupId,
      ]);
      return groups.isNotEmpty ? groups.first.notification : '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> updateGroupAnnouncement(String notification) async {
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(groupId, notification: notification);
      return true;
    } catch (e) {
      state = state.copyWith(error: '群公告更新失败: $e');
      return false;
    }
  }

  Future<bool> inviteMembers(List<String> memberIds) async {
    final ok = await ref
        .read(groupMemberProvider(groupId).notifier)
        .inviteMembers(memberIds);
    if (!ok) {
      state = state.copyWith(error: '邀请成员失败');
    }
    return ok;
  }
}
