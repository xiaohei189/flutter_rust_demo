import 'package:flutter/material.dart';

import '../main.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_list_item.dart';
import 'chat_detail_screen.dart';

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
    final conversations = messageService.conversations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          // 显示同步状态
          if (messageService.isSyncingConversations)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: messageService.syncProgress > 0
                        ? messageService.syncProgress / 100
                        : null,
                  ),
                ),
              ),
            )
          else
            // 显示连接状态
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Icon(
                  messageService.isConnected
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color: messageService.isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await messageService.refreshConversations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 新建聊天
            },
          ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (messageService.isSyncingConversations) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '正在同步会话... ${messageService.syncProgress}%',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ] else ...[
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无会话',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      messageService.isConnected
                          ? '等待接收消息...'
                          : 'WebSocket 未连接',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final im_conv.LocalConversation conversation =
                    conversations[index];
                return ChatListItem(
                  conversation: conversation,
                  onTap: () async {
                    // 进入前先拉取最后一屏消息，再打开详情，避免进入后滚动抖动
                    await messageService.loadHistoryMessages(
                      conversation.conversationId,
                      count: 20,
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          conversation: conversation,
                          preLoaded: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
