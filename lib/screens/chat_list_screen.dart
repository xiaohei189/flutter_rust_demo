import 'package:flutter/material.dart';
import '../widgets/chat_list_item.dart';
import 'chat_detail_screen.dart';
import '../main.dart';

/// 聊天列表页面
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    // 监听消息服务的变化
    messageService.addListener(_onMessageServiceChanged);
  }

  @override
  void dispose() {
    messageService.removeListener(_onMessageServiceChanged);
    super.dispose();
  }

  void _onMessageServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = messageService.chats;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          // 显示连接状态
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Icon(
                messageService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: messageService.isConnected ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 新建聊天
            },
          ),
        ],
      ),
      body: chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无会话',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    messageService.isConnected
                        ? '等待接收消息...'
                        : 'WebSocket 未连接',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
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



