import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/group_repository.dart';
import '../services/group_service.dart';
import '../ui/features/groups/view_models/create_group_view_model.dart';
import '../ui/features/groups/view_models/group_application_view_model.dart';
import '../ui/features/groups/view_models/group_list_view_model.dart';
import '../ui/features/groups/view_models/group_member_view_model.dart';
import 'im_providers.dart';
import 'message_service_provider.dart';

// ==================== 群组列表 Provider ====================

/// 群组 Repository Provider
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(
    groupService: GroupService.instance,
    imClient: ref.watch(imClientProvider),
  );
});

/// 群组列表 ViewModel Provider
final groupListProvider =
    StateNotifierProvider<GroupListViewModel, GroupListState>((ref) {
      final viewModel = GroupListViewModel(
        repository: ref.watch(groupRepositoryProvider),
      );
      ref.listen(messageServiceProvider, (prev, next) {
        if (prev?.groupRevision != next.groupRevision) {
          viewModel.loadGroups();
        }
      });
      return viewModel;
    });

// ==================== 群成员 Provider ====================

/// 群成员 Provider（Family，按群组 ID）
final groupMemberProvider =
    StateNotifierProvider.family<
      GroupMemberViewModel,
      GroupMemberState,
      String
    >((ref, groupId) {
      final viewModel = GroupMemberViewModel(
        repository: ref.watch(groupRepositoryProvider),
        groupId: groupId,
      );
      ref.listen(messageServiceProvider, (prev, next) {
        if (prev?.groupRevision != next.groupRevision) {
          viewModel.loadMembers();
        }
      });
      return viewModel;
    });

// ==================== 群申请 Provider ====================

/// 群申请列表 Provider
final groupApplicationProvider =
    StateNotifierProvider<GroupApplicationViewModel, GroupApplicationState>((
      ref,
    ) {
      final viewModel = GroupApplicationViewModel(
        repository: ref.watch(groupRepositoryProvider),
      );
      ref.listen(messageServiceProvider, (prev, next) {
        if (prev?.groupRevision != next.groupRevision) {
          viewModel.loadApplications();
        }
      });
      return viewModel;
    });

// ==================== 创建群组 Provider ====================

/// 创建群组 Provider
final createGroupProvider =
    StateNotifierProvider<CreateGroupViewModel, CreateGroupState>((ref) {
      return CreateGroupViewModel(
        repository: ref.watch(groupRepositoryProvider),
      );
    });
