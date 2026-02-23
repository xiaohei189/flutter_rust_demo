import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_list_item.dart';
import '../widgets/conversation_title_bar.dart';
import 'chat_detail_screen.dart';

/// 聊天列表页面
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Timer? _delayRefreshTimer;

  @override
  void initState() {
    super.initState();
    messageService.addListener(_onMessageServiceChanged);
    // 进入列表页后延迟 3 秒再拉一次会话，避免服务端同步未完成时一直为空
    _delayRefreshTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && messageService.conversations.isEmpty) {
        messageService.refreshConversations();
      }
    });
  }

  @override
  void dispose() {
    _delayRefreshTimer?.cancel();
    messageService.removeListener(_onMessageServiceChanged);
    super.dispose();
  }

  void _onMessageServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  static const _backgroundColor = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final conversations = messageService.conversations;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: ConversationTitleBar(
        currentUserId: messageService.currentUserId,
        nickname: null,
        avatarUrl: null,
        isSyncing: messageService.isSyncingConversations,
        isConnected: messageService.isConnected,
        syncProgress: messageService.syncProgress,
        onRefresh: () => messageService.refreshConversations(),
        onAddFriend: () {
          // TODO: 添加好友
        },
        onAddGroup: () {
          // TODO: 加群
        },
        onCreateGroup: () {
          // TODO: 建群
        },
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
              padding: EdgeInsets.zero,
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final im_conv.LocalConversation conversation =
                    conversations[index];
                return ChatListItem(
                  conversation: conversation,
                  currentUserId: messageService.currentUserId.isNotEmpty
                      ? messageService.currentUserId
                      : null,
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
