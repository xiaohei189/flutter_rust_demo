import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/models/user_profile.dart';

/// 用户头像：本地路径持久化、持久目录复制与展示 URL 解析。
class UserAvatarStore {
  UserAvatarStore();

  static const _kLocalAvatarPathKey = 'user_local_avatar_path';

  Future<String?> loadLocalAvatarPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kLocalAvatarPathKey);
    } catch (e) {
      appLog.e('[UserProfile] loadLocalAvatarPath 失败: $e');
      return null;
    }
  }

  Future<void> saveLocalAvatarPath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path != null) {
        await prefs.setString(_kLocalAvatarPathKey, path);
        appLog.i('[UserProfile] saveLocalAvatarPath: 已保存 path=$path');
      } else {
        await prefs.remove(_kLocalAvatarPathKey);
        appLog.i('[UserProfile] saveLocalAvatarPath: 已清除路径');
      }
    } catch (e) {
      appLog.e('[UserProfile] saveLocalAvatarPath 失败: $e');
    }
  }

  /// 检查 URL 是否为有效的头像 URL（不是模拟 URL）
  bool isValidAvatarUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    if (url.contains('example.com')) {
      return false;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return true;
    }
    return false;
  }

  /// 获取用于显示的头像 URL：本地路径 > 服务器 URL（如果有效）
  String? resolveDisplayUrl({
    required String? localAvatarPath,
    required UserProfile? profile,
  }) {
    if (localAvatarPath != null &&
        localAvatarPath.isNotEmpty &&
        File(localAvatarPath).existsSync()) {
      return localAvatarPath;
    }
    if (isValidAvatarUrl(profile?.faceUrl)) {
      return profile?.faceUrl;
    }
    return null;
  }

  /// 从 URL 中提取文件名
  String extractFileName(String url) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final paths = uri.pathSegments;
    if (paths.isEmpty) return '';
    return paths.last;
  }

  /// 为 URL 添加缓存清除参数
  String addCacheBuster(String url) {
    if (url.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$url${separator}_t=$timestamp';
  }

  /// 把本地头像复制到持久目录，避免临时文件被清理。
  Future<String> persistLocalAvatar(String sourcePath) async {
    var savedPath = sourcePath;
    final source = File(sourcePath);
    if (source.existsSync()) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        savedPath =
            '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await source.copy(savedPath);
        appLog.i('[UserProfile] 已复制头像到持久目录: $savedPath');
      } catch (e) {
        appLog.e('[UserProfile] 复制头像失败，保留原路径: $e');
      }
    }
    return savedPath;
  }
}
