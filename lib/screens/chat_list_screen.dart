import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_list_item.dart';
import '../widgets/conversation_title_bar.dart';
import 'chat_detail_screen.dart';

/// 会话列表页：顶部栏、搜索栏、会话列表（长按/左滑删除）
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Timer? _delayRefreshTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    messageService.addListener(_onMessageServiceChanged);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _delayRefreshTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && messageService.conversations.isEmpty) {
        messageService.refreshConversations();
      }
    });
  }

  @override
  void dispose() {
    _delayRefreshTimer?.cancel();
    _searchController.dispose();
    messageService.removeListener(_onMessageServiceChanged);
    super.dispose();
  }

  void _onMessageServiceChanged() {
    if (mounted) setState(() {});
  }

  List<im_conv.LocalConversation> get _filteredConversations {
    final list = messageService.conversations;
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((c) {
      final name = c.showName.isNotEmpty ? c.showName : c.conversationId;
      return name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _filteredConversations;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ConversationTitleBar(
        currentUserId: messageService.currentUserId,
        nickname: null,
        avatarUrl: null,
        isSyncing: messageService.isSyncingConversations,
        isConnected: messageService.isConnected,
        syncProgress: messageService.syncProgress,
        onRefresh: () => messageService.refreshConversations(),
        onAddFriend: () {},
        onAddGroup: () {},
        onCreateGroup: () {},
        onScan: () {},
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索联系人、群组及聊天记录',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 22,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (messageService.isSyncingConversations) ...[
                          const CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '正在同步会话... ${messageService.syncProgress}%',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '暂无会话',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            messageService.isConnected
                                ? '等待接收消息...'
                                : 'WebSocket 未连接',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    key: ValueKey<int>(conversations.length),
                    padding: EdgeInsets.zero,
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final im_conv.LocalConversation conversation =
                          conversations[index];
                      return ChatListItem(
                        key: ValueKey<String>(conversation.conversationId),
                        conversation: conversation,
                        itemIndex: index,
                        currentUserId: messageService.currentUserId.isNotEmpty
                            ? messageService.currentUserId
                            : null,
                        onTap: () async {
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
                        onDelete: () {
                          messageService.removeConversation(
                            conversation.conversationId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已删除会话'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onPinToggle: () {
                          // TODO: 对接 SDK 置顶/取消置顶
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: const Text('置顶功能开发中'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onMarkRead: () {
                          // TODO: 对接 SDK 标为已读
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: const Text('标为已读功能开发中'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
