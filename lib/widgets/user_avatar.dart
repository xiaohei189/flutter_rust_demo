import 'dart:io';

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';

/// 用户头像组件 - 支持网络图片、本地图片、颜色图标
class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatar;
    appLog.i('[UserAvatar] 构建头像, userId: ${user.id}, avatar: $avatarUrl');

    // 如果是本地文件路径
    if (avatarUrl != null && _isLocalPath(avatarUrl)) {
      appLog.i('[UserAvatar] 使用本地图片: $avatarUrl');
      final file = File(avatarUrl);
      appLog.i('[UserAvatar] 文件是否存在: ${file.existsSync()}, 大小: ${file.existsSync() ? file.lengthSync() : 0} bytes');

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.file(
            file,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              appLog.e('[UserAvatar] 本地图片加载失败: $error');
              return _buildFallbackAvatar();
            },
          ),
        ),
      );
    }

    // 如果有网络图片且可用
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final urlWithCache = _buildCacheBustedUrl(avatarUrl);
      appLog.i('[UserAvatar] 使用网络图片: $urlWithCache');

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(urlWithCache),
        onBackgroundImageError: (exception, stackTrace) {
          appLog.e('[UserAvatar] 网络图片加载失败: $exception');
        },
        child: Container(),
      );
    }

    // 使用默认头像
    appLog.i('[UserAvatar] 使用默认头像');
    return _buildFallbackAvatar();
  }

  /// 构建默认头像
  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(user.avatarColor),
      child: Icon(
        Icons.person,
        size: radius * 1.2,
        color: Colors.white,
      ),
    );
  }

  /// 判断是否为本地文件路径
  bool _isLocalPath(String path) {
    appLog.i('[UserAvatar] 检查是否为本地路径: $path');
    
    // 先检查是否是网络协议（http://, https://, ftp:// 等）
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('ftp://')) {
      appLog.i('[UserAvatar] 检测到网络 URL');
      return false;
    }
    
    // Windows 路径（如 C:\Users\... 或 D:/...）
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(path)) {
      appLog.i('[UserAvatar] 检测到 Windows 路径');
      return true;
    }
    
    // Unix 绝对路径（如 /data/user/0/...）
    if (path.startsWith('/')) {
      appLog.i('[UserAvatar] 检测到 Unix 绝对路径');
      return true;
    }
    
    appLog.i('[UserAvatar] 不是本地路径');
    return false;
  }

  /// 构建带缓存清除参数的 URL
  String _buildCacheBustedUrl(String url) {
    if (url.contains('_t=') || url.contains('_cb=')) {
      return url;
    }
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}_cb=${user.id}';
  }
}
