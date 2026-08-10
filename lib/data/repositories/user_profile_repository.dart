import '../services/user_service.dart';
import '../../domain/models/user_profile.dart';
import 'friend_repository.dart';
import 'friend_search_repository.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> fetchProfile(String userId);
  bool isCurrentUser(String userId);
  Future<bool> isFriend(String userId);
  Future<void> sendFriendRequest(String userId, String reqMsg);
}

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({
    required UserService userService,
    required FriendRepository friendRepository,
    required FriendSearchRepository friendSearchRepository,
  })  : _userService = userService,
        _friendRepository = friendRepository,
        _friendSearchRepository = friendSearchRepository;

  final UserService _userService;
  final FriendRepository _friendRepository;
  final FriendSearchRepository _friendSearchRepository;

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final profile = await _userService.fetchUserProfile(userId);
    return profile == null ? null : UserProfileMapping.fromUserInfo(profile);
  }

  @override
  bool isCurrentUser(String userId) {
    return _userService.currentUserId == userId;
  }

  @override
  Future<bool> isFriend(String userId) {
    return _friendRepository.isFriend(userId);
  }

  @override
  Future<void> sendFriendRequest(String userId, String reqMsg) {
    return _friendSearchRepository.sendFriendRequest(userId, reqMsg);
  }
}
