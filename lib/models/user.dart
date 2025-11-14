import 'package:flutter/material.dart';

/// 用户模型
class User {
  final String id;
  final String name;
  final String? avatar; // 改为可选，不依赖网络图片
  final String? status; // 在线状态
  final Color? avatarColor; // 头像背景颜色
  final IconData? avatarIcon; // 头像图标

  User({
    required this.id,
    required this.name,
    this.avatar,
    this.status,
    this.avatarColor,
    this.avatarIcon,
  });

  // 模拟数据 - 使用颜色和图标代替网络图片
  static User currentUser = User(
    id: '1',
    name: '我',
    avatarColor: Colors.blue,
    avatarIcon: Icons.person,
  );

  static List<User> mockUsers = [
    User(
      id: '2',
      name: '张三',
      status: '在线',
      avatarColor: Colors.orange,
      avatarIcon: Icons.face,
    ),
    User(
      id: '3',
      name: '李四',
      status: '离线',
      avatarColor: Colors.green,
      avatarIcon: Icons.account_circle,
    ),
    User(
      id: '4',
      name: '王五',
      status: '在线',
      avatarColor: Colors.purple,
      avatarIcon: Icons.person_outline,
    ),
  ];
}
