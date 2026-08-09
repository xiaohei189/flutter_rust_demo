import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/blacklist_repository.dart';
import '../data/repositories/friend_application_repository.dart';
import '../data/repositories/friend_repository.dart';
import '../data/repositories/friend_search_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../ui/contacts/view_models/black_list_view_model.dart';
import '../ui/contacts/view_models/friend_apply_view_model.dart';
import '../ui/contacts/view_models/friend_list_view_model.dart';
import '../ui/contacts/view_models/friend_search_view_model.dart';
import 'im_providers.dart';
import 'message_service_provider.dart';

// ==================== 好友列表 ====================

/// 好友 Repository Provider
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepositoryImpl(
    friendService: FriendService.instance,
    imClient: ref.watch(imClientProvider),
  );
});

/// 好友列表 ViewModel Provider
final friendListProvider =
    StateNotifierProvider<FriendListViewModel, FriendListState>((ref) {
      final viewModel = FriendListViewModel(
        repository: ref.watch(friendRepositoryProvider),
      );
      ref.listen(messageServiceProvider, (prev, next) {
        if (prev?.friendRevision != next.friendRevision) {
          viewModel.loadFriends();
        }
      });
      return viewModel;
    });

// ==================== 好友申请 ====================

/// 好友申请 Repository Provider
final friendApplicationRepositoryProvider =
    Provider<FriendApplicationRepository>((ref) {
      return FriendApplicationRepositoryImpl(
        friendService: FriendService.instance,
        imClient: ref.watch(imClientProvider),
      );
    });

/// 好友申请 ViewModel Provider
final friendApplyProvider =
    StateNotifierProvider<FriendApplyViewModel, FriendApplyState>((ref) {
      final viewModel = FriendApplyViewModel(
        repository: ref.watch(friendApplicationRepositoryProvider),
      );
      ref.listen(messageServiceProvider, (prev, next) {
        if (prev?.friendRevision != next.friendRevision) {
          viewModel.loadApplications();
        }
      });
      return viewModel;
    });

// ==================== 好友搜索 ====================

/// 好友搜索 Repository Provider
final friendSearchRepositoryProvider = Provider<FriendSearchRepository>((ref) {
  return FriendSearchRepositoryImpl(
    friendService: FriendService.instance,
    imClient: ref.watch(imClientProvider),
  );
});

/// 用户资料 Repository Provider
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(
    userService: UserService.instance,
    friendRepository: ref.watch(friendRepositoryProvider),
    friendSearchRepository: ref.watch(friendSearchRepositoryProvider),
  );
});

/// 好友搜索 ViewModel Provider
final friendSearchProvider =
    StateNotifierProvider<FriendSearchViewModel, FriendSearchState>((ref) {
      return FriendSearchViewModel(
        repository: ref.watch(friendSearchRepositoryProvider),
      );
    });

// ==================== 黑名单 ====================

/// 黑名单 Repository Provider
final blackListRepositoryProvider = Provider<BlacklistRepository>((ref) {
  return BlacklistRepositoryImpl(
    friendService: FriendService.instance,
    userService: ref.watch(userServiceProvider),
    imClient: ref.watch(imClientProvider),
  );
});

/// 黑名单 ViewModel Provider
final blackListProvider =
    StateNotifierProvider<BlackListViewModel, BlackListState>((ref) {
      final viewModel = BlackListViewModel(
        repository: ref.watch(blackListRepositoryProvider),
      );
      ref.listen(messageServiceProvider, (prev, next) {
        if (prev?.friendRevision != next.friendRevision) {
          viewModel.load();
        }
      });
      return viewModel;
    });
