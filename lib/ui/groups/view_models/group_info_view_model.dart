import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/models/conversation.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../../providers/current_user_provider.dart';
import '../../../providers/im_providers.dart';
import '../../chat/providers/conversation_provider.dart';
import '../providers/group_provider.dart';

/// 群信息页状态
class GroupInfoState {
  final bool initialized;
  final bool isLoading;
  final String groupName;
  final String groupDescription;
  /// 本地乐观更新的头像 URL（含缓存穿透参数），优先于会话数据展示
  final String? localAvatarUrl;
  final String? error;

  const GroupInfoState({
    this.initialized = false,
    this.isLoading = false,
    this.groupName = '群聊',
    this.groupDescription = '暂无描述',
    this.localAvatarUrl,
    this.error,
  });

  GroupInfoState copyWith({
    bool? initialized,
    bool? isLoading,
    String? groupName,
    String? groupDescription,
    String? localAvatarUrl,
    bool clearLocalAvatarUrl = false,
    String? error,
    bool clearError = false,
  }) {
    return GroupInfoState(
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      groupName: groupName ?? this.groupName,
      groupDescription: groupDescription ?? this.groupDescription,
      localAvatarUrl: clearLocalAvatarUrl
          ? null
          : (localAvatarUrl ?? this.localAvatarUrl),
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
    final avatar =
        state.localAvatarUrl ??
        (conv != null && conv.faceUrl.isNotEmpty ? conv.faceUrl : null);
    if (conv == null) {
      return User(id: arg, name: '未知群组', avatar: avatar);
    }
    return User(
      id: groupId,
      name: state.groupName,
      avatar: avatar,
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
      // 本地立即生效（带时间戳穿透缓存），不等服务端回包
      state = state.copyWith(localAvatarUrl: _addCacheBuster(url));
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

  /// 为头像 URL 添加时间戳参数，绕过 ImageCache 旧图缓存
  String _addCacheBuster(String url) {
    if (url.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}_t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 上传头像文件到服务器，返回可访问的图片 URL
  Future<String> uploadAvatar(String filePath) {
    appLog.i('[GroupInfo] 开始上传群头像: $filePath');
    final service = ref.read(mediaUploadServiceProvider);
    return service.uploadFile(filePath: filePath, fileName: 'group_avatar.jpg');
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
