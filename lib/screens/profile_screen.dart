import 'package:flutter/material.dart';

import '../models/user.dart';
import '../widgets/user_avatar.dart';

/// 个人中心页面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = User.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 用户信息卡片
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                UserAvatar(user: user, radius: 40),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'ID: ${user.id}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.qr_code), onPressed: () {}),
              ],
            ),
          ),
          const Divider(height: 1),

          // 功能列表
          _buildMenuItem(Icons.settings, '设置', () {}),
          _buildMenuItem(Icons.notifications, '通知', () {}),
          _buildMenuItem(Icons.privacy_tip, '隐私', () {}),
          _buildMenuItem(Icons.help, '帮助与反馈', () {}),
          _buildMenuItem(Icons.info, '关于', () {}),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
