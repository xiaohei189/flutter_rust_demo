import 'package:flutter/material.dart';
import '../../../domain/models/user.dart';
import '../../previews/app_theme_preview.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

/// 会话列表/顶部栏统一使用的头像半径，保证名字大小与字体一致。
const double kConversationAvatarRadius = 26;

/// 名字占位头像的统一底色：取自飞书参考图（RGB ≈ 74,132,255）。
const Color kNameAvatarBackground = Color(0xFF4A84FF);

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

  /// 构建默认头像：全名（自适应缩放）+ 统一品牌底色，保证底色一致。
  Widget _buildFallbackAvatar(BuildContext context) {
    final colors = context.appColors;
    final label = _labelOf(user.name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: kNameAvatarBackground,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: radius * 0.22,
          vertical: radius * 0.08,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: colors.onPrimary,
              // 与旁边标题字号一致（r=26 时约 16），避免头像名字比标题还大。
              fontSize: radius * 0.62,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// 取展示名：空值回退为问号；名字较短直接展示全名，过长则取前 4 字再加省略号。
  static String _labelOf(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    if (n.length <= 4) return n;
    return '${n.substring(0, 4)}…';
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
      return true;
    }

    // Unix 绝对路径（如 /data/user/0/...）
    if (path.startsWith('/')) {
      return true;
    }

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

// ==================== 预览 ====================

@AppThemePreview(name: '默认头像（不同尺寸）', group: 'UserAvatar')
Widget userAvatarDefaultPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(user: User.mockUsers[0], radius: 20),
        const SizedBox(width: 12),
        UserAvatar(user: User.mockUsers[1], radius: 28),
        const SizedBox(width: 12),
        UserAvatar(user: User.mockUsers[2], radius: 36),
      ],
    ),
  );
}
