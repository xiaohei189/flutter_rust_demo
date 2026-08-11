import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'group_filter_panel.dart';
import '../../core/widgets/segmented_toggle.dart';

/// 分组筛选类型
typedef GroupFilterCallback = void Function(GroupFilter filter);

/// ChatList 筛选栏组件
/// 包含分组菜单按钮和分段控制器
class ChatListHeader extends StatelessWidget {
  const ChatListHeader({
    super.key,
    required this.activeFilter,
    required this.totalUnreadCount,
    required this.isQuickTab,
    required this.isSyncing,
    required this.syncProgress,
    required this.onFilterChange,
    required this.onOpenGroupFilter,
  });

  final GroupFilter activeFilter;
  final int totalUnreadCount;
  final bool isQuickTab;
  final bool isSyncing;
  final int syncProgress;
  final ValueChanged<GroupFilter> onFilterChange;
  final VoidCallback onOpenGroupFilter;

  String get _activeFilterLabel {
    switch (activeFilter) {
      case GroupFilter.all:
        return '消息';
      case GroupFilter.unread:
        return '未读';
      case GroupFilter.flagged:
        return '标记';
      case GroupFilter.atMe:
        return '@我';
      case GroupFilter.singleChat:
        return '单聊';
      case GroupFilter.groupChat:
        return '群组';
      case GroupFilter.done:
        return '已完成';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenGroupFilter,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tune, size: 18, color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: 10),
          if (isQuickTab)
            SegmentedToggle(
              segments: [
                '消息',
                totalUnreadCount > 0 ? '未读 $totalUnreadCount' : '未读',
                if (activeFilter == GroupFilter.flagged) '标记',
              ],
              selectedIndex: activeFilter == GroupFilter.all
                  ? 0
                  : activeFilter == GroupFilter.unread
                  ? 1
                  : 2,
              onChanged: (i) {
                switch (i) {
                  case 0:
                    onFilterChange(GroupFilter.all);
                    break;
                  case 1:
                    onFilterChange(GroupFilter.unread);
                    break;
                  case 2:
                    onFilterChange(GroupFilter.flagged);
                    break;
                }
              },
            )
          else
            GestureDetector(
              onTap: () => onFilterChange(GroupFilter.all),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _activeFilterLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.close, size: 14, color: colors.primary),
                  ],
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}
