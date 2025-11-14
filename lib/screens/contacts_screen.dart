import 'package:flutter/material.dart';

import '../models/user.dart';
import '../widgets/user_avatar.dart';

/// 联系人页面
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // TODO: 添加好友
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: User.mockUsers.length,
        itemBuilder: (context, index) {
          final user = User.mockUsers[index];
          return ListTile(
            leading: UserAvatar(user: user),
            title: Text(user.name),
            subtitle: Text(user.status ?? '离线'),
            trailing: user.status == '在线'
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () {
              // TODO: 查看用户详情
            },
          );
        },
      ),
    );
  }
}
