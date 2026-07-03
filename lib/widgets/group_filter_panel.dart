import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 分组筛选类型
enum GroupFilter {
  all,
  unread,
  flagged,
  atMe,
  singleChat,
  groupChat,
  done,
}

/// 分组筛选面板（从左侧滑入，占满屏幕高度，宽度约 80%）
class GroupFilterPanel extends StatelessWidget {
  const GroupFilterPanel({
    super.key,
    required this.activeFilter,
    required this.totalMessages,
    required this.unreadCount,
    required this.groupCount,
    required this.onSelect,
  });

  final GroupFilter activeFilter;
  final int totalMessages;
  final int unreadCount;
  final int groupCount;
  final ValueChanged<GroupFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final panelWidth = MediaQuery.of(context).size.width * 0.80;

    return GestureDetector(
      onTap: () => AppRouter.goBack(context),
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
                            onTap: () => AppRouter.goBack(context),
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
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          _buildItem(
                            icon: Icons.chat_bubble_outline,
                            label: '消息',
                            count: totalMessages,
                            filter: GroupFilter.all,
                          ),
                          _buildItem(
                            icon: Icons.mark_email_unread,
                            label: '未读',
                            count: unreadCount,
                            filter: GroupFilter.unread,
                          ),
                          _buildItem(
                            icon: Icons.flag_outlined,
                            label: '标记',
                            count: 0,
                            filter: GroupFilter.flagged,
                          ),
                          _buildItem(
                            icon: Icons.alternate_email,
                            label: '@我',
                            count: 0,
                            filter: GroupFilter.atMe,
                          ),
                          _buildItem(
                            icon: Icons.person_outline,
                            label: '单聊',
                            count: totalMessages - groupCount,
                            filter: GroupFilter.singleChat,
                          ),
                          _buildItem(
                            icon: Icons.group_outlined,
                            label: '群组',
                            count: groupCount,
                            filter: GroupFilter.groupChat,
                          ),
                          _buildItem(
                            icon: Icons.done_all_outlined,
                            label: '已完成',
                            count: 0,
                            filter: GroupFilter.done,
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
    required int count,
    required GroupFilter filter,
  }) {
    final isActive = activeFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 16),
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
              if (count > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                  ),
                ),
              if (isActive)
                Icon(
                  Icons.check,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 从左侧滑入的路由动画
class LeftSlideRoute extends PageRouteBuilder<void> {
  final Widget child;

  LeftSlideRoute({required this.child})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.4, 0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}
