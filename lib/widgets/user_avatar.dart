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
}



