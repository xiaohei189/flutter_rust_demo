import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../view_models/chat_list_view_model.dart';
import 'chat_list_item_content.dart';

/// 会话列表项长按菜单（对齐设计稿交互）：
/// 1) 被长按的会话行就地高亮成一张白色圆角卡片；
/// 2) 在其旁边（空间不够则上方）单独弹出一张操作卡片（项数按可用回调动态生成）；
/// 3) 其余列表被遮罩变暗，点遮罩关闭。
Future<void> showChatListItemMenu(
  BuildContext context, {
  required Rect rowRect,
  required Conversation conversation,
  required bool isMuted,
  VoidCallback? onPinToggle,
  VoidCallback? onMarkRead,
  VoidCallback? onMarkUnread,
  VoidCallback? onMuteToggle,
  VoidCallback? onClear,
  VoidCallback? onFlagToggle,
  VoidCallback? onDoneToggle,
  VoidCallback? onArchive,
  VoidCallback? onUnarchive,
  VoidCallback? onMoveToFolder,
  VoidCallback? onDelete,
}) {
  // 根 Overlay：菜单可覆盖到底部导航栏，且该区域可交互。
  final overlay = Overlay.of(context, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
  final overlayHeight = overlayBox.size.height;
  final overlayWidth = overlayBox.size.width;
  final colors = context.appColors;

  const highlightMargin = 8.0;
  final highlightWidth = overlayWidth - highlightMargin * 2;

  // 行矩形转成 overlay 内坐标（overlay = 会话列表 body 区域，不含底部导航）。
  final double rowTop = (rowRect.top - overlayOrigin.dy)
      .clamp(0.0, overlayHeight - 60)
      .toDouble();
  // 高亮行真实高度 = 原行高度，保证正好盖住那一行。
  final double rowHeight = rowRect.height.clamp(40, 120);

  const menuWidth = 168.0;
  const actionHeight = 50.0;
  // 菜单最高贴近整屏（上下各留 12 的呼吸位）；项数超出时卡片内部滚动，
  // 避免「长按行位于屏幕中部」时菜单顶出可视区。
  final maxMenuHeight = math.max(120.0, overlayHeight - 24);
  // 估算项数只用于首帧定位：6 项固定 + 归档/移动分组/清空/删除（按可用回调计），
  // 布局完成后会用实测高度精确校正。
  final estimatedActionCount =
      6 +
      ((onArchive != null || onUnarchive != null) ? 1 : 0) +
      (onMoveToFolder != null ? 1 : 0) +
      (onClear != null ? 1 : 0) +
      (onDelete != null ? 1 : 0);
  final estimatedMenuHeight = math.min(
    estimatedActionCount * actionHeight,
    maxMenuHeight,
  );
  // 先用估算定位（根据空间决定在上/在下），布局后再用实测高度精确校正。
  final belowFitsEstimate =
      rowTop + rowHeight + estimatedMenuHeight + 6 < overlayHeight;
  var menuTop = belowFitsEstimate
      ? rowTop + rowHeight + 6
      : (rowTop - estimatedMenuHeight - 6)
            .clamp(0.0, math.max(0.0, overlayHeight - estimatedMenuHeight))
            .toDouble();

  final completer = Completer<void>();
  late final OverlayEntry entry;
  final rowKey = GlobalKey();
  final menuKey = GlobalKey();

  void close() {
    if (!completer.isCompleted) completer.complete();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final hasUnread =
          ChatListViewModel.effectiveUnreadCount(conversation) > 0;
      return Stack(
        children: [
          // 遮罩：点击关闭；让其余列表变暗。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              // 就地菜单遮罩：比 mediaScrim 更轻，避免盖住被高亮的会话行
              child: ColoredBox(
                color: colors.mediaScrim.withValues(alpha: 0.4),
              ),
            ),
          ),
          // ① 就地高亮的选中行（白色圆角卡片）。
          Positioned(
            left: highlightMargin,
            top: rowTop,
            width: highlightWidth,
            height: rowHeight,
            child: Material(
              key: rowKey,
              color: colors.surface,
              // 长按浮层卡片：与其它浮层（悬停工具条/工具栏面板）统一 12
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              elevation: 6,
              shadowColor: colors.shadow,
              clipBehavior: Clip.antiAlias,
              child: ChatListItemContent(
                conversation: conversation,
                isSelected: false,
                onTap: () {},
                onLongPress: (_) {},
                contentHorizontalPadding: 8,
              ),
            ),
          ),
          // ② 独立操作卡片（项数按可用回调动态生成，超标时内部滚动）。
          Positioned(
            left: highlightMargin,
            top: menuTop,
            width: menuWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxMenuHeight),
              child: Material(
                key: menuKey,
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                elevation: 6,
                shadowColor: colors.shadow,
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuAction(
                        ctx,
                        icon: Icons.push_pin_outlined,
                        label: conversation.isPinned ? '取消置顶' : '置顶',
                        onTap: () {
                          close();
                          onPinToggle?.call();
                        },
                      ),
                      _menuAction(
                        ctx,
                        icon: hasUnread
                            ? Icons.done_all_outlined
                            : Icons.mark_email_unread,
                        label: hasUnread ? '标为已读' : '标为未读',
                        onTap: () {
                          close();
                          (hasUnread ? onMarkRead : onMarkUnread)?.call();
                        },
                      ),
                      _menuAction(
                        ctx,
                        icon: ChatListViewModel.isFlagged(conversation)
                            ? Icons.flag
                            : Icons.flag_outlined,
                        label: ChatListViewModel.isFlagged(conversation)
                            ? '取消标记'
                            : '标记',
                        onTap: () {
                          close();
                          onFlagToggle?.call();
                        },
                      ),
                      _menuAction(
                        ctx,
                        icon: Icons.label_outline,
                        label: '标签',
                        // 会话标签体系未落地：先给明确反馈，不留「点了没反应」。
                        onTap: () {
                          close();
                          _notSupported(context, '标签');
                        },
                      ),
                      _menuAction(
                        ctx,
                        icon: isMuted
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_none,
                        label: isMuted ? '取消免打扰' : '消息免打扰',
                        onTap: () {
                          close();
                          onMuteToggle?.call();
                        },
                      ),
                      _menuAction(
                        ctx,
                        icon: ChatListViewModel.isDone(conversation)
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        label: ChatListViewModel.isDone(conversation)
                            ? '取消已完成'
                            : '完成',
                        onTap: () {
                          close();
                          onDoneToggle?.call();
                        },
                      ),
                      if (onArchive != null || onUnarchive != null) ...[
                        _menuDivider(colors),
                        _menuAction(
                          ctx,
                          icon: Icons.inventory_2_outlined,
                          label: ChatListViewModel.isArchived(conversation)
                              ? '取消归档'
                              : '归档',
                          onTap: () {
                            final archive =
                                !ChatListViewModel.isArchived(conversation);
                            close();
                            (archive ? onArchive : onUnarchive)?.call();
                          },
                        ),
                      ],
                      if (onMoveToFolder != null)
                        _menuAction(
                          ctx,
                          icon: Icons.drive_file_move_outline,
                          label: '移动到分组',
                          onTap: () {
                            close();
                            onMoveToFolder();
                          },
                        ),
                      if (onClear != null) ...[
                        _menuDivider(colors),
                        _menuAction(
                          ctx,
                          icon: Icons.cleaning_services_outlined,
                          label: '清空聊天记录',
                          onTap: () async {
                            close();
                            final confirmed = await _confirmMenuAction(
                              context,
                              title: '清空聊天记录',
                              message: '确定清空该会话的聊天记录吗？该操作不可恢复。',
                              confirmLabel: '清空',
                            );
                            if (confirmed) onClear();
                          },
                        ),
                      ],
                      if (onDelete != null)
                        _menuAction(
                          ctx,
                          icon: Icons.delete_outline,
                          label: '删除',
                          color: colors.danger,
                          onTap: () async {
                            close();
                            final confirmed = await _confirmMenuAction(
                              context,
                              title: '删除会话',
                              message: '确定删除该会话吗？聊天记录将一并删除。',
                              confirmLabel: '删除',
                            );
                            if (confirmed) onDelete();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);

  // 布局完成后实测高亮行真实高度，校正菜单位置（在上/在下）。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final rowBox = rowKey.currentContext?.findRenderObject() as RenderBox?;
    final menuBox = menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox == null ||
        !rowBox.attached ||
        menuBox == null ||
        !menuBox.attached) {
      return;
    }
    final rowOffset = rowBox.localToGlobal(Offset.zero);
    final rowTopLocal = rowOffset.dy - overlayOrigin.dy;
    final rowBottomLocal = rowTopLocal + rowBox.size.height;
    // 用实测菜单高度，保证“向上”和“向下”间隙一致（均为 6）。
    final actualMenuHeight = menuBox.size.height;
    // 菜单比可视区还高时上界会小于下界，先收敛到 0，避免 clamp 抛异常。
    final maxTop = math.max(0.0, overlayHeight - actualMenuHeight);
    final belowFits = rowBottomLocal + actualMenuHeight + 6 < overlayHeight;
    final newTop = belowFits
        ? math.min(rowBottomLocal + 6, maxTop)
        : (rowTopLocal - actualMenuHeight - 6)
              .clamp(0.0, maxTop)
              .toDouble();
    if ((newTop - menuTop).abs() > 0.5) {
      menuTop = newTop;
      entry.markNeedsBuild();
    }
  });

  return completer.future;
}

/// 纯图标 + 文字的操作行。
Widget _menuAction(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  Color? color,
}) {
  final colors = context.appColors;
  final foreground = color ?? colors.textPrimary;
  return InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: foreground),
            const SizedBox(width: 12),
            // 文案最长 6 个字（清空聊天记录）：留出省略保护，避免增加项后横向溢出。
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: foreground),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 菜单分组之间的细分隔线（与卡片留白配合，不额外撑高）。
Widget _menuDivider(AppColors colors) {
  return Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: colors.divider.withValues(alpha: 0.6),
  );
}

/// 尚未开放的功能：与聊天设置页一致，给一次性提示。
void _notSupported(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('「$label」暂未开放'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1200),
    ),
  );
}

/// 破坏性操作的二次确认（清空 / 删除会话）。
Future<bool> _confirmMenuAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final danger = context.appColors.danger;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: danger)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
