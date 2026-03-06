import 'package:flutter/material.dart';
import '../models/user.dart';

/// 用户头像组件 - 支持网络图片、颜色图标、首字母
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
    // 如果有网络图片且可用
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user.avatar!),
        onBackgroundImageError: (_, __) {
          // 图片加载失败时的处理
        },
        child: Container(), // 防止加载失败时显示空白
      );
    }

    // 使用颜色和图标
    if (user.avatarColor != null && user.avatarIcon != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: user.avatarColor,
        child: Icon(
          user.avatarIcon,
          size: radius * 1.2,
          color: Colors.white,
        ),
      );
    }

    final initials = _getInitials(user.name);
    final fontSize = initials.length <= 1
        ? radius * 0.8
        : initials.length <= 2
            ? radius * 0.7
            : radius * 0.48;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _getColorFromName(user.name),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }

  /// 根据名字获取展示文字：
  /// - 有中文：取第一个中文字符
  /// - 多个英文单词：取首字母缩写（如 "John Doe" → "JD"）
  /// - 单个英文单词且 ≤ 6 字符：显示完整名字（如 "alice" → "alice"）
  /// - 单个英文单词且 > 6 字符：截取前 4 字符（如 "xiaoming11" → "xiao"）
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final cnMatch = RegExp(r'[\u4e00-\u9fa5]').firstMatch(name);
    if (cnMatch != null) {
      return cnMatch.group(0)!;
    }

    final trimmed = name.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    if (trimmed.length <= 6) return trimmed;
    return trimmed.substring(0, 4);
  }

  /// 根据名字生成颜色
  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.red,
    ];

    final hashCode = name.hashCode.abs();
    return colors[hashCode % colors.length];
  }
}



