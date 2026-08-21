import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_rust_demo/domain/models/user_profile.dart'
    show UserProfile;

import 'message_service_provider.dart';

/// 群组数据版本（SDK 事件推进，视图模型据此触发刷新）
final groupRevisionProvider = Provider<int>((ref) {
  return ref.watch(messageServiceProvider.select((s) => s.groupRevision));
});

/// 好友数据版本（SDK 事件推进，视图模型据此触发刷新）
final friendRevisionProvider = Provider<int>((ref) {
  return ref.watch(messageServiceProvider.select((s) => s.friendRevision));
});

/// 登录用户资料（全局唯一来源）
final loginUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(messageServiceProvider.select((s) => s.loginUserProfile));
});
