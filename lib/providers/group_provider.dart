import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/group_service.dart';
import '../src/rust/api/client.dart' as fb;
import '../src/rust/domain/model/group.dart' show GroupInfo, GroupMember;
import '../src/rust/domain/ports/group.dart' show GroupApplyInfo;
import '../utils/app_logger.dart';
import 'message_service_provider.dart';

// ==================== 群组列表 Provider ====================

/// 群组列表状态
class GroupListState {
  final List<GroupInfo> groups;
  final bool isLoading;
  final String? error;

  const GroupListState({
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });

  GroupListState copyWith({
    List<GroupInfo>? groups,
    bool? isLoading,
    String? error,
  }) {
    return GroupListState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 群组列表 Notifier
class GroupListNotifier extends StateNotifier<GroupListState> {
  GroupListNotifier(this._ref) : super(const GroupListState());

  final Ref _ref;

  /// 获取客户端实例
  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 加载群组列表
  Future<void> loadGroups() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final groups = await GroupService.instance.getGroupList(client);
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e) {
      appLog.e('[GroupListProvider] 加载群组列表失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: '加载群组列表失败: $e',
      );
    }
  }

  /// 刷新群组列表
  Future<void> refreshGroups() async {
    await loadGroups();
  }
}

/// 群组列表 Provider
final groupListProvider =
    StateNotifierProvider<GroupListNotifier, GroupListState>((ref) {
  return GroupListNotifier(ref);
});

// ==================== 群成员 Provider ====================

/// 群成员列表状态
class GroupMemberState {
  final List<GroupMember> members;
  final bool isLoading;
  final String? error;

  const GroupMemberState({
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  GroupMemberState copyWith({
    List<GroupMember>? members,
    bool? isLoading,
    String? error,
  }) {
    return GroupMemberState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 群成员 Notifier（按群组 ID 区分）
class GroupMemberNotifier extends StateNotifier<GroupMemberState> {
  GroupMemberNotifier(this._ref, this._groupId)
      : super(const GroupMemberState());

  final Ref _ref;
  final String _groupId;

  /// 获取客户端实例
  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 加载群成员列表
  Future<void> loadMembers() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final members = await GroupService.instance.getGroupMembers(
        client,
        groupId: _groupId,
      );
      state = state.copyWith(members: members, isLoading: false);
    } catch (e) {
      appLog.e('[GroupMemberProvider] 加载群成员失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: '加载群成员失败: $e',
      );
    }
  }

  /// 邀请成员加入群组
  Future<bool> inviteMembers(List<String> memberIds) async {
    final client = _client;
    if (client == null) return false;

    try {
      await GroupService.instance.inviteGroupMembers(
        client,
        groupId: _groupId,
        memberIds: memberIds,
      );
      // 邀请成功后重新加载成员列表
      await loadMembers();
      return true;
    } catch (e) {
      appLog.e('[GroupMemberProvider] 邀请成员失败: $e');
      state = state.copyWith(error: '邀请成员失败: $e');
      return false;
    }
  }

  /// 踢出群成员
  Future<bool> kickMembers(List<String> memberIds) async {
    final client = _client;
    if (client == null) return false;

    try {
      await GroupService.instance.kickGroupMembers(
        client,
        groupId: _groupId,
        memberIds: memberIds,
      );
      // 踢出成功后重新加载成员列表
      await loadMembers();
      return true;
    } catch (e) {
      appLog.e('[GroupMemberProvider] 踢出成员失败: $e');
      state = state.copyWith(error: '踢出成员失败: $e');
      return false;
    }
  }
}

/// 群成员 Provider（Family，按群组 ID）
final groupMemberProvider = StateNotifierProvider.family<
    GroupMemberNotifier, GroupMemberState, String>((ref, groupId) {
  return GroupMemberNotifier(ref, groupId);
});

// ==================== 群申请 Provider ====================

/// 群申请列表状态
class GroupApplicationState {
  final List<GroupApplyInfo> received;
  final List<GroupApplyInfo> sent;
  final bool isLoading;
  final String? error;

  const GroupApplicationState({
    this.received = const [],
    this.sent = const [],
    this.isLoading = false,
    this.error,
  });

  GroupApplicationState copyWith({
    List<GroupApplyInfo>? received,
    List<GroupApplyInfo>? sent,
    bool? isLoading,
    String? error,
  }) {
    return GroupApplicationState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 未处理的申请数量
  int get unhandledCount => received.where((a) => a.handleResult == 0).length;
}

/// 群申请 Notifier
class GroupApplicationNotifier extends StateNotifier<GroupApplicationState> {
  GroupApplicationNotifier(this._ref) : super(const GroupApplicationState());

  final Ref _ref;

  /// 获取客户端实例
  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 加载群申请列表（同时获取收到的和发出的）
  Future<void> loadApplications() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        GroupService.instance.getGroupApplicationListAsRecipient(client),
        GroupService.instance.getGroupApplicationListAsApplicant(client),
      ]);
      state = state.copyWith(
        received: results[0],
        sent: results[1],
        isLoading: false,
      );
    } catch (e) {
      appLog.e('[GroupApplicationProvider] 加载群申请列表失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: '加载群申请列表失败: $e',
      );
    }
  }

  /// 接受群申请
  Future<bool> acceptApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await GroupService.instance.acceptGroupApplication(
        client,
        groupId: groupId,
        userId: userId,
        handleMsg: handleMsg,
      );
      // 接受后重新加载列表
      await loadApplications();
      return true;
    } catch (e) {
      appLog.e('[GroupApplicationProvider] 接受群申请失败: $e');
      state = state.copyWith(error: '接受群申请失败: $e');
      return false;
    }
  }

  /// 拒绝群申请
  Future<bool> refuseApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await GroupService.instance.refuseGroupApplication(
        client,
        groupId: groupId,
        userId: userId,
        handleMsg: handleMsg,
      );
      // 拒绝后重新加载列表
      await loadApplications();
      return true;
    } catch (e) {
      appLog.e('[GroupApplicationProvider] 拒绝群申请失败: $e');
      state = state.copyWith(error: '拒绝群申请失败: $e');
      return false;
    }
  }
}

/// 群申请列表 Provider
final groupApplicationProvider =
    StateNotifierProvider<GroupApplicationNotifier, GroupApplicationState>(
        (ref) {
  return GroupApplicationNotifier(ref);
});

// ==================== 创建群组 Provider ====================

/// 创建群组状态
class CreateGroupState {
  final bool isCreating;
  final GroupInfo? createdGroup;
  final List<String> selectedMemberIds;
  final String? error;

  const CreateGroupState({
    this.isCreating = false,
    this.createdGroup,
    this.selectedMemberIds = const [],
    this.error,
  });

  CreateGroupState copyWith({
    bool? isCreating,
    GroupInfo? createdGroup,
    List<String>? selectedMemberIds,
    String? error,
    bool clearCreatedGroup = false,
  }) {
    return CreateGroupState(
      isCreating: isCreating ?? this.isCreating,
      createdGroup:
          clearCreatedGroup ? null : (createdGroup ?? this.createdGroup),
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      error: error,
    );
  }
}

/// 创建群组 Notifier
class CreateGroupNotifier extends StateNotifier<CreateGroupState> {
  CreateGroupNotifier(this._ref) : super(const CreateGroupState());

  final Ref _ref;

  /// 获取客户端实例
  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 设置已选成员列表
  void setSelectedMembers(List<String> memberIds) {
    state = state.copyWith(selectedMemberIds: memberIds);
  }

  /// 添加一个已选成员
  void addSelectedMember(String userId) {
    if (!state.selectedMemberIds.contains(userId)) {
      state = state.copyWith(
        selectedMemberIds: [...state.selectedMemberIds, userId],
      );
    }
  }

  /// 移除一个已选成员
  void removeSelectedMember(String userId) {
    state = state.copyWith(
      selectedMemberIds:
          state.selectedMemberIds.where((id) => id != userId).toList(),
    );
  }

  /// 创建群组
  Future<GroupInfo?> createGroup({
    required String groupName,
    required int groupType,
  }) async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return null;
    }

    if (state.selectedMemberIds.isEmpty) {
      state = state.copyWith(error: '请至少选择一名成员');
      return null;
    }

    state = state.copyWith(isCreating: true, error: null);
    try {
      final group = await GroupService.instance.createGroup(
        client,
        groupName: groupName,
        groupType: groupType,
        memberIds: state.selectedMemberIds,
      );
      state = state.copyWith(
        isCreating: false,
        createdGroup: group,
        selectedMemberIds: [],
      );
      appLog.i('[CreateGroupProvider] 创建群组成功: ${group.groupId}');
      return group;
    } catch (e) {
      appLog.e('[CreateGroupProvider] 创建群组失败: $e');
      state = state.copyWith(
        isCreating: false,
        error: '创建群组失败: $e',
      );
      return null;
    }
  }

  /// 重置状态
  void reset() {
    state = const CreateGroupState();
  }
}

/// 创建群组 Provider
final createGroupProvider =
    StateNotifierProvider<CreateGroupNotifier, CreateGroupState>((ref) {
  return CreateGroupNotifier(ref);
});
