import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/services.dart';
import '../../../domain/models/user_profile.dart';
import '../../chat/providers/message_revision_provider.dart';
import '../view_models/user_profile_view_model.dart';

/// 用户服务实例 Provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserServiceImpl();
});

/// 当前登录用户资料流 Provider
final loginUserStreamProvider = StreamProvider<UserProfile?>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.loginUserStream;
});

/// 当前登录用户资料 Provider
final loginUserProvider = Provider<UserProfile?>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.loginUserProfile;
});

/// 用户资料缓存流 Provider
final userProfilesStreamProvider = StreamProvider<Map<String, UserProfile>>((ref) {
  final service = ref.watch(userServiceProvider);
  return service.profilesStream;
});

/// 指定用户资料 Provider（Family）（从新服务）
final userProfileByIdProvider = Provider.family<UserProfile?, String>((
  ref,
  userId,
) {
  final service = ref.watch(userServiceProvider);
  return service.getUserProfile(userId);
});

/// 用户资料本地编辑状态 Provider（头像覆盖、加载、错误）
final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileLocalState>(
      UserProfileNotifier.new,
    );

/// 用户资料展示状态 Provider：服务端资料（单一来源）+ 本地编辑状态派生。
final userProfileViewProvider = Provider<UserProfileState>((ref) {
  final local = ref.watch(userProfileProvider);
  final server = ref.watch(loginUserProfileProvider);
  if (server == null) {
    return UserProfileState(
      localAvatarPath: local.localAvatarPath,
      isLoading: local.isLoading,
      error: local.error,
    );
  }
  var profile = server;
  final localAvatarUrl = local.localAvatarUrl;
  if (localAvatarUrl != null) {
    profile = server.copyWith(faceUrl: localAvatarUrl);
  }
  return UserProfileState.fromServerProfile(
    profile,
    localAvatarPath: local.localAvatarPath,
  ).copyWith(isLoading: local.isLoading, error: local.error);
});

/// 当前用户资料 Provider（仅返回 profile）
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userProfileViewProvider).profile;
});

/// 当前用户昵称 Provider
final currentUserNicknameProvider = Provider<String>((ref) {
  return ref.watch(userProfileViewProvider).nickname;
});

/// 当前用户别名 Provider
final currentUserAliasProvider = Provider<String>((ref) {
  return ref.watch(userProfileViewProvider).alias;
});

/// 当前用户签名 Provider
final currentUserSignatureProvider = Provider<String>((ref) {
  return ref.watch(userProfileViewProvider).signature;
});

/// 用户资料加载状态 Provider
final userProfileLoadingProvider = Provider<bool>((ref) {
  return ref.watch(userProfileViewProvider).isLoading;
});

/// 用户资料错误 Provider
final userProfileErrorProvider = Provider<String?>((ref) {
  return ref.watch(userProfileViewProvider).error;
});
