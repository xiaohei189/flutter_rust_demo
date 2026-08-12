import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../../providers/current_user_provider.dart';
import '../../chat/providers/conversation_provider.dart';
import '../providers/group_provider.dart';

/// 群信息页状态
class GroupInfoState {
  final bool initialized;
  final bool isLoading;
  final String groupName;
  final String groupDescription;
  final String? error;

  const GroupInfoState({
    this.initialized = false,
    this.isLoading = false,
    this.groupName = '群聊',
    this.groupDescription = '暂无描述',
    this.error,
  });

  GroupInfoState copyWith({
    bool? initialized,
    bool? isLoading,
    String? groupName,
    String? groupDescription,
    String? error,
    bool clearError = false,
  }) {
    return GroupInfoState(
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      groupName: groupName ?? this.groupName,
      groupDescription: groupDescription ?? this.groupDescription,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 群信息 ViewModel：负责群资料编辑与群成员管理操作。
class GroupInfoViewModel extends FamilyNotifier<GroupInfoState, String> {
  @override
  GroupInfoState build(String conversationId) {
    return const GroupInfoState();
  }

  GroupInfoState get currentState => state;

  Conversation? get conversation {
    final newService = ref.read(conversationServiceProvider);
    final fromService = newService.getConversation(arg);
    if (fromService != null) return fromService;
    return ref
        .read(conversationListProvider)
        .conversations
        .where((c) => c.conversationId == arg)
        .firstOrNull;
  }

  String get groupId {
    final conv = conversation;
    if (conv == null) return arg;
    return conv.groupId.isNotEmpty ? conv.groupId : arg;
  }

  User get groupUser {
    final conv = conversation;
    if (conv == null) {
      return User(id: arg, name: '未知群组', avatar: null);
    }
    return User(
      id: groupId,
      name: state.groupName,
      avatar: conv.faceUrl.isNotEmpty ? conv.faceUrl : null,
    );
  }

  List<GroupMember> get members =>
      ref.read(groupMemberProvider(groupId)).members;

  String get currentUserId => ref.read(currentUserIdProvider);

  GroupMember? get currentMember =>
      members.where((m) => m.userId == currentUserId).firstOrNull;

  bool get isOwner {
    final member = currentMember;
    return member?.roleLevel == 3;
  }

  bool get canManage {
    final member = currentMember;
    return member != null && member.roleLevel >= 2;
  }

  Future<void> load() async {
    if (state.initialized) return;
    final conv = conversation;
    state = state.copyWith(
      initialized: true,
      groupName: conv?.showName.isNotEmpty == true ? conv!.showName : '群聊',
      groupDescription: '暂无描述',
    );
    if (conv != null) {
      await loadMembers();
    }
  }

  Future<void> loadMembers() {
    return ref.read(groupMemberProvider(groupId).notifier).loadMembers();
  }

  Future<bool> updateGroupName(String value) async {
    state = state.copyWith(clearError: true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(groupId, groupName: value);
      state = state.copyWith(groupName: value);
      return true;
    } catch (e) {
      state = state.copyWith(error: '群名称更新失败: $e');
      return false;
    }
  }

  Future<bool> updateGroupDescription(String value) async {
    state = state.copyWith(clearError: true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(groupId, introduction: value);
      state = state.copyWith(groupDescription: value.isEmpty ? '暂无描述' : value);
      return true;
    } catch (e) {
      state = state.copyWith(error: '群描述更新失败: $e');
      return false;
    }
  }

  Future<bool> updateGroupAvatar(String url) async {
    state = state.copyWith(clearError: true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(groupId, faceUrl: url);
      await ref.read(conversationListProvider.notifier).refreshConversations();
      return true;
    } catch (e) {
      state = state.copyWith(error: '更新失败: $e');
      return false;
    }
  }

  Future<bool> kickMember(String userId) {
    return _memberAction(
      () =>
          ref.read(groupMemberProvider(groupId).notifier).kickMembers([userId]),
      fallback: '踢出成员失败',
    );
  }

  Future<bool> muteMember(String userId, int seconds) {
    return _memberAction(
      () => ref
          .read(groupMemberProvider(groupId).notifier)
          .muteMember(userId, seconds),
      fallback: '禁言失败',
    );
  }

  Future<bool> unmuteMember(String userId) {
    return _memberAction(
      () =>
          ref.read(groupMemberProvider(groupId).notifier).unmuteMember(userId),
      fallback: '取消禁言失败',
    );
  }

  Future<bool> setAdmin(String userId, bool isAdmin) {
    return _memberAction(
      () => ref
          .read(groupMemberProvider(groupId).notifier)
          .setMemberRole(userId, isAdmin ? 2 : 1),
      fallback: '设置管理员失败',
    );
  }

  Future<bool> muteAll(bool isMute) {
    return _memberAction(
      () => ref.read(groupMemberProvider(groupId).notifier).muteAll(isMute),
      fallback: '全员禁言操作失败',
    );
  }

  Future<bool> transferOwner(String userId) {
    return _memberAction(
      () =>
          ref.read(groupMemberProvider(groupId).notifier).transferOwner(userId),
      fallback: '转让群主失败',
    );
  }

  Future<bool> dismissGroup() async {
    final ok = await _memberAction(
      () => ref.read(groupMemberProvider(groupId).notifier).dismissGroup(),
      fallback: '解散群组失败',
    );
    if (ok) {
      await ref.read(groupListProvider.notifier).loadGroups();
    }
    return ok;
  }

  Future<bool> _memberAction(
    Future<bool> Function() action, {
    required String fallback,
  }) async {
    state = state.copyWith(clearError: true);
    final ok = await action();
    if (!ok) {
      state = state.copyWith(
        error: ref.read(groupMemberProvider(groupId)).error ?? fallback,
      );
    }
    return ok;
  }
}
