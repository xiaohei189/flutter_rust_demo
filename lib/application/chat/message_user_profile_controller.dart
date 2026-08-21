import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/data/services/login_storage.dart';
import 'package:flutter_rust_demo/domain/models/user_profile.dart'
    show UserProfile;
import 'package:flutter_rust_demo/core/utils/app_logger.dart';

import 'message_service_notifier.dart';

/// 当前登录用户资料：拉取、批量预加载与更新。
class MessageUserProfileController {
  MessageUserProfileController(this.service, this.imClient, this.repository);

  final MessageServiceNotifier service;
  final ImClient imClient;
  final MessageRepository repository;

  bool get _isClientReady => imClient.isInitialized;

  /// 拉取当前登录用户资料（通过批量接口 getUsersInfo，走缓存）并更新内存缓存
  Future<UserProfile?> refreshLoginUserProfile() async {
    final state = service.currentState;
    if (!_isClientReady || state.currentUserId.isEmpty) return null;
    try {
      final list = await repository.getUsersInfo([state.currentUserId]);
      final profile = list.isNotEmpty ? list.first : null;
      if (profile != null) {
        final newUserProfiles = Map<String, UserProfile>.from(
          state.userProfiles,
        );
        newUserProfiles[profile.userId] = profile;
        service.updateState(
          state.copyWith(
            loginUserProfile: profile,
            userProfiles: newUserProfiles,
          ),
        );
      }
      return profile;
    } catch (e) {
      appLog.e('[MessageService] 拉取当前用户资料失败: $e');
      return null;
    }
  }

  /// 批量预加载用户资料
  Future<void> preloadUserProfiles(List<String> userIds) async {
    if (!_isClientReady || userIds.isEmpty) return;
    final uniq = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uniq.isEmpty) return;
    try {
      final list = await repository.getUsersInfo(uniq);
      final state = service.currentState;
      final newUserProfiles = Map<String, UserProfile>.from(state.userProfiles);
      for (final p in list) {
        newUserProfiles[p.userId] = p;
      }
      service.updateState(state.copyWith(userProfiles: newUserProfiles));
    } catch (e) {
      appLog.w('[MessageService] 批量拉取用户资料失败: $e');
    }
  }

  Future<UserProfile?> updateLoginUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
    int? globalRecvMsgOpt,
  }) async {
    if (!_isClientReady) {
      try {
        appLog.i('[MessageService] client 为 null，尝试重新初始化');
        final credentials = await LoginStorage.loadCredentials();
        if (credentials != null) {
          appLog.i('[MessageService] 找到保存的凭证，尝试重新初始化');
          await service.initialize(
            userId: credentials.userId,
            imToken: credentials.imToken,
          );
        } else {
          appLog.w('[MessageService] 没有找到保存的凭证，无法重新初始化');
        }
      } catch (e) {
        appLog.e('[MessageService] 重新初始化失败: $e');
      }
    }

    if (!_isClientReady) return null;

    try {
      await repository.updateUserProfile(
        nickname: nickname,
        faceUrl: faceUrl,
        ex: ex,
      );
      return await refreshLoginUserProfile();
    } catch (e) {
      appLog.e('[MessageService] 更新当前用户资料失败: $e');
      return null;
    }
  }
}
