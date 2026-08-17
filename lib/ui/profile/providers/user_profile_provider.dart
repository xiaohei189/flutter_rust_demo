import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/services.dart';
import '../../../domain/models/user_profile.dart';
import '../view_models/user_profile_view_model.dart';

/// 用户服务实例 Provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserServiceImpl();
});

/// 当前登录用户资料流 Provider
final loginUserStreamProvider = StreamProvider<UserInfo?>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.loginUserStream;
});

/// 当前登录用户资料 Provider
final loginUserProvider = Provider<UserInfo?>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.loginUserProfile;
});

/// 用户资料缓存流 Provider
final userProfilesStreamProvider = StreamProvider<Map<String, UserInfo>>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.profilesStream;
});

/// 指定用户资料 Provider（Family）（从新服务）
final userProfileByIdProvider = Provider.family<UserInfo?, String>((
  ref,
  userId,
) {
  final service = ref.watch(userServiceProvider);
  return service.getUserProfile(userId);
});

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
      UserProfileNotifier.new,
    );

/// 当前用户资料 Provider（仅返回 profile）
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userProfileProvider).profile;
});

/// 当前用户昵称 Provider
final currentUserNicknameProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).nickname;
});

/// 当前用户别名 Provider
final currentUserAliasProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).alias;
});

/// 当前用户签名 Provider
final currentUserSignatureProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).signature;
});

/// 用户资料加载状态 Provider
final userProfileLoadingProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider).isLoading;
});

/// 用户资料错误 Provider
final userProfileErrorProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).error;
});
