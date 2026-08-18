import 'package:flutter/material.dart';

import '../../previews/app_theme_preview.dart';
import '../../core/theme/app_theme.dart';

/// 多选工具栏：已选数量、全选/取消全选、关闭与消息操作。
class MessageSelectionTopBar extends StatelessWidget {
  const MessageSelectionTopBar({
    super.key,
    required this.count,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClose,
    required this.onDelete,
    required this.onForwardOneByOne,
    required this.onMergeForward,
  });

  final int count;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onForwardOneByOne;
  final VoidCallback onMergeForward;

  bool get _allSelected => totalCount > 0 && count >= totalCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasSelection = count > 0;
    return Container(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: '取消',
                ),
                Expanded(
                  child: Text(
                    '已选 $count 项',
                    style: TextStyle(fontSize: 15, color: colors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: onSelectAll,
                  child: Text(_allSelected ? '取消全选' : '全选'),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: colors.divider.withValues(alpha: 0.6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _MessageSelectionAction(
                  icon: Icons.forward,
                  label: '逐条转发',
                  enabled: hasSelection,
                  onTap: onForwardOneByOne,
                ),
                _MessageSelectionAction(
                  icon: Icons.library_add_outlined,
                  label: '合并转发',
                  enabled: hasSelection,
                  onTap: onMergeForward,
                ),
                _MessageSelectionAction(
                  icon: Icons.delete_outline,
                  label: '删除',
                  enabled: hasSelection,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageSelectionAction extends StatelessWidget {
  const _MessageSelectionAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = enabled
        ? colors.textPrimary
        : colors.textSecondary.withValues(alpha: 0.45);
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '多选工具栏（已选 3 条）', group: 'MessageSelectionTopBar')
Widget messageSelectionBarPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: MessageSelectionTopBar(
      count: 3,
      totalCount: 10,
      onSelectAll: _noop,
      onClose: _noop,
      onDelete: _noop,
      onForwardOneByOne: _noop,
      onMergeForward: _noop,
    ),
  );
}

void _noop() {}
