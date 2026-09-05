import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/models/conversation.dart';
import '../../../core/theme/app_theme.dart';
import '../../view_models/chat_list_view_model.dart';
import 'chat_list_item_content.dart';

/// 会话列表项长按菜单（对齐设计稿交互）：
/// 1) 被长按的会话行就地高亮成一张白色圆角卡片；
/// 2) 在其旁边（空间不够则上方）单独弹出一张 6 项操作卡片；
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
  final double rowTop =
      (rowRect.top - overlayOrigin.dy).clamp(0.0, overlayHeight - 60).toDouble();
  // 高亮行真实高度 = 原行高度，保证正好盖住那一行。
  final double rowHeight = rowRect.height.clamp(40, 120);

  const menuWidth = 148.0;
  const actionHeight = 50.0;
  final menuHeight = 6 * actionHeight;
  // 先用估算定位（根据空间决定在上/在下），布局后再用实测高度精确校正。
  final belowFitsEstimate =
      rowTop + rowHeight + menuHeight + 6 < overlayHeight;
  var menuTop = belowFitsEstimate
      ? rowTop + rowHeight + 6
      : (rowTop - menuHeight - 6).clamp(0.0, overlayHeight - menuHeight).toDouble();

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
      final hasUnread = ChatListViewModel.effectiveUnreadCount(conversation) > 0;
      return Stack(
        children: [
          // 遮罩：点击关闭；让其余列表变暗。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: const ColoredBox(color: Color(0x66000000)),
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
              borderRadius: BorderRadius.circular(10),
              elevation: 6,
              shadowColor: const Color(0x33000000),
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
          // ② 独立操作卡片（仅 6 项，不再内嵌会话行）。
          Positioned(
            left: highlightMargin,
            top: menuTop,
            width: menuWidth,
            child: Material(
              key: menuKey,
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 6,
              shadowColor: const Color(0x33000000),
              clipBehavior: Clip.antiAlias,
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
                    onTap: close, // 暂无数据，先占位
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
                ],
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
    final belowFits = rowBottomLocal + actualMenuHeight + 6 < overlayHeight;
    final newTop = belowFits
        ? rowBottomLocal + 6
        : (rowTopLocal - actualMenuHeight - 6)
              .clamp(0.0, overlayHeight - actualMenuHeight)
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
}) {
  final colors = context.appColors;
  return InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.textPrimary),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: colors.textPrimary)),
          ],
        ),
      ),
    ),
  );
}
