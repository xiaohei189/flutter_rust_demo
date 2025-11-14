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

    // 使用首字母作为头像
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getColorFromName(user.name),
      child: Text(
        _getInitials(user.name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 根据名字获取首字母
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    if (name.length == 1) return name.toUpperCase();
    
    // 中文名取最后一个字，英文名取首字母
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(name)) {
      return name.substring(name.length - 1); // 中文取最后一个字
    } else {
      // 英文取首字母
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name.substring(0, 1).toUpperCase();
    }
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



