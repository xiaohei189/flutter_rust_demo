import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/group_repository.dart';
import '../../../data/services/group_service.dart';
import '../../../providers/im_providers.dart';
import '../view_models/create_group_view_model.dart';
import '../view_models/group_application_view_model.dart';
import '../view_models/group_list_view_model.dart';
import '../view_models/group_member_view_model.dart';

// ==================== 群组列表 Provider ====================

/// 群组 Repository Provider
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(
    groupService: GroupService.instance,
    imClient: ref.watch(imClientProvider),
  );
});

/// 群组列表 ViewModel Provider
final groupListProvider = NotifierProvider<GroupListViewModel, GroupListState>(
  GroupListViewModel.new,
);

// ==================== 群成员 Provider ====================

/// 群成员 Provider（Family，按群组 ID）
final groupMemberProvider =
    NotifierProvider.family<GroupMemberViewModel, GroupMemberState, String>(
      GroupMemberViewModel.new,
    );

// ==================== 群申请 Provider ====================

/// 群申请列表 Provider
final groupApplicationProvider =
    NotifierProvider<GroupApplicationViewModel, GroupApplicationState>(
      GroupApplicationViewModel.new,
    );

// ==================== 创建群组 Provider ====================

/// 创建群组 Provider
final createGroupProvider =
    NotifierProvider<CreateGroupViewModel, CreateGroupState>(
      CreateGroupViewModel.new,
    );
