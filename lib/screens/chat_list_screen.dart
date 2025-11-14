import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../widgets/chat_list_item.dart';
import 'chat_detail_screen.dart';

/// 聊天列表页面
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 新建聊天
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: Chat.mockChats.length,
        itemBuilder: (context, index) {
          final chat = Chat.mockChats[index];
          return ChatListItem(
            chat: chat,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(chat: chat),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



