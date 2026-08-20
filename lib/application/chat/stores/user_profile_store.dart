import '../../../../domain/models/user_profile.dart';

class UserProfileStore {
  final String currentUserId;
  final Map<String, UserProfile> userProfiles;
  final UserProfile? loginUserProfile;

  const UserProfileStore({
    this.currentUserId = '',
    this.userProfiles = const {},
    this.loginUserProfile,
  });

  UserProfileStore copyWith({
    String? currentUserId,
    Map<String, UserProfile>? userProfiles,
    UserProfile? loginUserProfile,
    bool clearLoginUserProfile = false,
  }) {
    return UserProfileStore(
      currentUserId: currentUserId ?? this.currentUserId,
      userProfiles: userProfiles ?? this.userProfiles,
      loginUserProfile: clearLoginUserProfile
          ? null
          : loginUserProfile ?? this.loginUserProfile,
    );
  }
}