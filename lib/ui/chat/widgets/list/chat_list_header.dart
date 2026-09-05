import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'group_filter_panel.dart';
import '../../../core/widgets/segmented_toggle.dart';

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
    required this.onSearchTap,
    this.activeFolderLabel,
  });

  final GroupFilter activeFilter;
  final int totalUnreadCount;
  final bool isQuickTab;
  final bool isSyncing;
  final int syncProgress;
  final ValueChanged<GroupFilter> onFilterChange;
  final VoidCallback onOpenGroupFilter;
  final VoidCallback onSearchTap;
  final String? activeFolderLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onOpenGroupFilter,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 36,
                  height: 44,
                  child: Icon(Icons.menu, size: 26, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: SegmentedToggle(
                  height: 44,
                  activeColor: const Color(0xFF3370FF),
                  segments: [
                    '消息',
                    totalUnreadCount > 0 ? '未读 $totalUnreadCount' : '未读',
                    '标记',
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
                ),
              ),
              const Spacer(),
            ],
          ),
          if (isSyncing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '同步中 $syncProgress%',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: syncProgress / 100,
                      minHeight: 3,
                      backgroundColor: colors.surfaceMuted,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
