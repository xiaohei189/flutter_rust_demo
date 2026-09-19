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
  /// 头像地址（网络 URL / 本地路径 / asset）。为空时回退到名字首字头像。
  final String? avatarUrl;

  /// 缓存去重键（通常为用户 ID）。仅在不使用 [UserAvatar.fromUser] 时必填。
  final String? cacheKey;

  /// 无头像时的回退展示名。
  final String fallbackName;

  final double radius;

  /// [avatarUrl] 与 [cacheKey] 直接给定，避免为了画一个头像去构造 [User] 对象。
  const UserAvatar({
    super.key,
    required this.avatarUrl,
    this.cacheKey,
    this.fallbackName = '',
    this.radius = 20,
  });

  /// 从 [User] 构建（语义化命名，避免所有调用点都改成传 [avatarUrl]）。
  UserAvatar.fromUser({super.key, required User user, this.radius = 20})
    : avatarUrl = user.avatar,
      cacheKey = user.id,
      fallbackName = user.name;

  /// Windows 绝对路径（`C:\...`）。提升为静态常量，避免每帧重新编译正则
  /// （会话列表/联系人列表里每个头像都会调用 [_isLocalPath]）。
  static final RegExp _windowsPathPattern = RegExp(r'^[a-zA-Z]:[\\/]');

  static bool _isRemoteUrl(String path) =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('ftp://');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final source = avatarUrl;

    // 如果是本地文件路径
    if (source != null && _isLocalPath(source)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colors.surfaceMuted,
        child: ClipOval(
          child: AppImage(
            source: source,
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
    if (source != null && source.isNotEmpty) {
      final urlWithCache = _buildCacheBustedUrl(source);
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
    final label = _labelOf(fallbackName);
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
  static bool _isLocalPath(String path) {
    // 先检查是否是网络协议（http://, https://, ftp:// 等）
    if (_isRemoteUrl(path)) {
      return false;
    }

    // Windows 路径（如 C:\Users\... 或 D:/...）
    if (_windowsPathPattern.hasMatch(path)) {
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
    return '$url${separator}_cb=${cacheKey ?? ''}';
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
        UserAvatar.fromUser(user: User.mockUsers[0], radius: 20),
        const SizedBox(width: 12),
        UserAvatar.fromUser(user: User.mockUsers[1], radius: 28),
        const SizedBox(width: 12),
        UserAvatar.fromUser(user: User.mockUsers[2], radius: 36),
      ],
    ),
  );
}
