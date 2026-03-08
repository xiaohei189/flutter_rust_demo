import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_list_item.dart';
import '../widgets/conversation_title_bar.dart';
import 'chat_detail_screen.dart';
import 'my_profile_screen.dart';
import 'profile_drawer_screen.dart';
import 'search_screen.dart';

/// 会话列表页（参考飞书风格）
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

/// 分组筛选类型
enum _GroupFilter {
  all,
  unread,
  flagged,
  atMe,
  singleChat,
  groupChat,
  done,
}

class _ChatListScreenState extends State<ChatListScreen> {
  Timer? _delayRefreshTimer;
  _GroupFilter _activeFilter = _GroupFilter.all;

  @override
  void initState() {
    super.initState();
    messageService.addListener(_onMessageServiceChanged);
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
    if (mounted) setState(() {});
  }

  int get _totalUnreadCount {
    int sum = 0;
    for (final c in messageService.conversations) {
      sum += c.unreadCount;
    }
    return sum;
  }

  int get _groupChatCount {
    return messageService.conversations
        .where((c) => c.conversationType == 2 || c.conversationType == 3)
        .length;
  }

  List<im_conv.LocalConversation> get _filteredConversations {
    var list = messageService.conversations;

    switch (_activeFilter) {
      case _GroupFilter.unread:
        list = list.where((c) => c.unreadCount > 0).toList();
        break;
      case _GroupFilter.singleChat:
        list = list.where((c) => c.conversationType == 1).toList();
        break;
      case _GroupFilter.groupChat:
        list = list
            .where((c) =>
                c.conversationType == 2 || c.conversationType == 3)
            .toList();
        break;
      case _GroupFilter.flagged:
      case _GroupFilter.atMe:
      case _GroupFilter.done:
        list = [];
        break;
      case _GroupFilter.all:
        break;
    }

    return list;
  }

  /// 消息/未读/标记 属于快捷 Tab，其他筛选不在 Tab 中
  bool get _isQuickTab =>
      _activeFilter == _GroupFilter.all ||
      _activeFilter == _GroupFilter.unread ||
      _activeFilter == _GroupFilter.flagged;

  /// 当前筛选的显示标签
  String get _activeFilterLabel {
    switch (_activeFilter) {
      case _GroupFilter.all:
        return '消息';
      case _GroupFilter.unread:
        return '未读';
      case _GroupFilter.flagged:
        return '标记';
      case _GroupFilter.atMe:
        return '@我';
      case _GroupFilter.singleChat:
        return '单聊';
      case _GroupFilter.groupChat:
        return '群组';
      case _GroupFilter.done:
        return '已完成';
    }
  }

  void _openGroupFilterPanel() {
    final totalUnread = _totalUnreadCount;
    final totalMessages = messageService.conversations.length;
    final groupCount = _groupChatCount;

    Navigator.of(context).push(_LeftSlideRoute(
      child: _GroupFilterPanel(
        activeFilter: _activeFilter,
        totalMessages: totalMessages,
        unreadCount: totalUnread,
        groupCount: groupCount,
        onSelect: (filter) {
          Navigator.pop(context);
          setState(() => _activeFilter = filter);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _filteredConversations;
    final totalUnread = _totalUnreadCount;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ConversationTitleBar(
        currentUserId: messageService.currentUserId,
        nickname: messageService.loginUserProfile?.nickname,
        avatarUrl: messageService.loginUserProfile?.faceUrl,
        isSyncing: messageService.isSyncingConversations,
        isConnected: messageService.isConnected,
        syncProgress: messageService.syncProgress,
        onAvatarTap: () {
          Navigator.of(context).push(_LeftSlideRoute(
            child: ProfileDrawerScreen(
              onOpenMyProfile: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyProfileScreen(),
                    ),
                  );
                });
              },
            ),
          ));
        },
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        },
        onRefresh: () => messageService.refreshConversations(),
        onAddFriend: () {},
        onAddGroup: () {},
        onCreateGroup: () {},
        onScan: () {},
      ),
      body: Column(
        children: [
          // 筛选栏：菜单图标 + 分段控制器
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
            child: Row(
              children: [
                // 分组菜单按钮
                GestureDetector(
                  onTap: _openGroupFilterPanel,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune,
                      size: 18,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_isQuickTab)
                  _SegmentedToggle(
                    segments: [
                      '消息',
                      totalUnread > 0 ? '未读 $totalUnread' : '未读',
                      if (_activeFilter == _GroupFilter.flagged) '标记',
                    ],
                    selectedIndex: _activeFilter == _GroupFilter.all
                        ? 0
                        : _activeFilter == _GroupFilter.unread
                            ? 1
                            : 2,
                    onChanged: (i) => setState(() {
                      switch (i) {
                        case 0:
                          _activeFilter = _GroupFilter.all;
                          break;
                        case 1:
                          _activeFilter = _GroupFilter.unread;
                          break;
                        case 2:
                          _activeFilter = _GroupFilter.flagged;
                          break;
                      }
                    }),
                  )
                else
                  GestureDetector(
                    onTap: () =>
                        setState(() => _activeFilter = _GroupFilter.all),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeFilterLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.close,
                              size: 14, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                if (messageService.isSyncingConversations)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // 会话列表
          Expanded(
            child: conversations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    key: ValueKey<int>(conversations.length),
                    padding: EdgeInsets.zero,
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return ChatListItem(
                        key: ValueKey<String>(conversation.conversationId),
                        conversation: conversation,
                        cachedUserProfile: conversation.userId.isNotEmpty
                            ? messageService.getUserProfile(conversation.userId)
                            : null,
                        itemIndex: index,
                        currentUserId:
                            messageService.currentUserId.isNotEmpty
                                ? messageService.currentUserId
                                : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => ChatDetailScreen(
                                conversation: conversation,
                                preLoaded: false,
                              ),
                              transitionsBuilder: (_, animation, __, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                    reverseCurve: Curves.easeInCubic,
                                  )),
                                  child: child,
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 180),
                              reverseTransitionDuration:
                                  const Duration(milliseconds: 150),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('置顶功能开发中'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onMarkRead: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('标为已读功能开发中'),
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

  Widget _buildEmptyState() {
    final label = _activeFilterLabel;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (messageService.isSyncingConversations) ...[
            const CircularProgressIndicator(color: AppTheme.primaryColor),
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
              _activeFilter == _GroupFilter.unread
                  ? Icons.done_all
                  : Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _activeFilter == _GroupFilter.all
                  ? '暂无会话'
                  : '「$label」中没有会话',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            if (_activeFilter == _GroupFilter.all) ...[
              const SizedBox(height: 8),
              Text(
                messageService.isConnected ? '等待接收消息...' : 'WebSocket 未连接',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 分段控制器：灰底圆角容器，白色滑块平滑滑动
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = segments.length;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(17),
      ),
      padding: const EdgeInsets.all(2),
      child: IntrinsicWidth(
        child: Stack(
          children: [
            // 隐藏占位层：不绘制但保留尺寸，撑出整体宽度
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(count, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    segments[i],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                )),
              ),
            ),
            // 滑块 + 文字
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segWidth = constraints.maxWidth / count;
                  return Stack(
                    children: [
                      // 白色滑块
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: segWidth * selectedIndex,
                        top: 0,
                        bottom: 0,
                        width: segWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      // 文字（唯一一层）
                      Row(
                        children: List.generate(count, (i) {
                          final isSelected = i == selectedIndex;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => onChanged(i),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  segments[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 从左侧滑入的路由动画
class _LeftSlideRoute extends PageRouteBuilder {
  final Widget child;

  _LeftSlideRoute({required this.child})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              )),
              child: child,
            );
          },
        );
}

/// 分组筛选面板（从左侧滑入，占满屏幕高度，宽度约 80%）
class _GroupFilterPanel extends StatelessWidget {
  const _GroupFilterPanel({
    required this.activeFilter,
    required this.totalMessages,
    required this.unreadCount,
    required this.groupCount,
    required this.onSelect,
  });

  final _GroupFilter activeFilter;
  final int totalMessages;
  final int unreadCount;
  final int groupCount;
  final ValueChanged<_GroupFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final panelWidth = MediaQuery.of(context).size.width * 0.80;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: panelWidth,
              height: double.infinity,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          const Text(
                            '分组',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.tune,
                              size: 20,
                              color: AppTheme.textSecondaryColor
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 筛选列表
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          _buildItem(
                            icon: Icons.chat_bubble_outline,
                            label: '消息',
                            count: totalMessages,
                            filter: _GroupFilter.all,
                          ),
                          _buildItem(
                            icon: Icons.loop,
                            label: '未读',
                            count: unreadCount,
                            filter: _GroupFilter.unread,
                          ),
                          _buildItem(
                            icon: Icons.flag_outlined,
                            label: '标记',
                            filter: _GroupFilter.flagged,
                          ),
                          _buildItem(
                            icon: Icons.alternate_email,
                            label: '@我',
                            filter: _GroupFilter.atMe,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 16),
                          ),
                          _buildItem(
                            icon: Icons.person_outline,
                            label: '单聊',
                            filter: _GroupFilter.singleChat,
                          ),
                          _buildItem(
                            icon: Icons.people_outline,
                            label: '群组',
                            count: groupCount,
                            filter: _GroupFilter.groupChat,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 16),
                          ),
                          _buildItem(
                            icon: Icons.check_circle_outline,
                            label: '已完成',
                            filter: _GroupFilter.done,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    int? count,
    required _GroupFilter filter,
  }) {
    final isActive = activeFilter == filter;

    return Material(
      color: isActive
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              if (count != null && count > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
