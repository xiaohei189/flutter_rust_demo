import 'package:flutter/material.dart';
import '../../../domain/models/user.dart';
import '../../../ui/core/utils/app_logger.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

/// 用户头像组件 - 支持网络图片、本地图片、颜色图标
class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatar;
    final colors = context.appColors;

    // 如果是本地文件路径
    if (avatarUrl != null && _isLocalPath(avatarUrl)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colors.surfaceMuted,
        child: ClipOval(
          child: AppImage(
            source: avatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            cacheWidth: radius * 2,
            errorWidget: _buildFallbackAvatar(context),
          ),
        ),
      );
    }

    // 如果有网络图片且可用
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final urlWithCache = _buildCacheBustedUrl(avatarUrl);
      return CircleAvatar(
        radius: radius,
        backgroundColor: colors.surfaceMuted,
        child: ClipOval(
          child: AppImage(
            source: urlWithCache,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            cacheWidth: radius * 2,
            errorWidget: _buildFallbackAvatar(context),
          ),
        ),
      );
    }

    // 使用默认头像
    return _buildFallbackAvatar(context);
  }

  /// 构建默认头像
  Widget _buildFallbackAvatar(BuildContext context) {
    final colors = context.appColors;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(user.avatarColor),
      child: Icon(Icons.person, size: radius * 1.2, color: colors.surface),
    );
  }

  /// 判断是否为本地文件路径
  bool _isLocalPath(String path) {
    // 先检查是否是网络协议（http://, https://, ftp:// 等）
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('ftp://')) {
      return false;
    }

    // Windows 路径（如 C:\Users\... 或 D:/...）
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(path)) {
      appLog.i('[UserAvatar] 检测到 Windows 路径');
      return true;
    }

    // Unix 绝对路径（如 /data/user/0/...）
    if (path.startsWith('/')) {
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
