import 'package:flutter/material.dart';

import '../../mappers/message_display.dart';
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../core/theme/app_theme.dart';
import '../composer/emoji_panel.dart' show EmojiPanel;
import 'message_action_menu.dart' show MessageActions, kMessageQuickReactions;

class MessageToolPanel extends StatefulWidget {
  const MessageToolPanel({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.actions,
    required this.reactions,
    required this.rootContext,
    required this.onClose,
  });

  final ChatMessage message;
  final String currentUserId;
  final MessageActions actions;
  final Set<String> reactions;
  final BuildContext rootContext;
  final VoidCallback onClose;

  /// 首屏高度占比（对齐飞书稿：约占屏幕一半）
  static const double initialHeightFactor = 0.5;
  static const double minHeightFactor = 0.3;
  static const double maxHeightFactor = 0.95;

  @override
  State<MessageToolPanel> createState() => MessageToolPanelState();
}

class MessageToolPanelState extends State<MessageToolPanel> {
  /// 点「⋯」切换到的完整表情界面
  bool _emojiOpen = false;

  /// 弹层高度占比：拖把手改它；切换内容（工具面板 ⇄ 表情界面）时保持不变
  double _heightFactor = MessageToolPanel.initialHeightFactor;

  bool get _isFromMe => widget.message.sendId == widget.currentUserId;

  bool get _canRevoke =>
      _isFromMe &&
      DateTime.now().difference(widget.message.sendDateTime).inMinutes < 2;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetHeight = screenHeight * _heightFactor;
    if (_emojiOpen) {
      // 表情界面：撑满当前弹层高度；首屏不滚动——拖动直接升抽屉，
      // 只有抽屉升到顶（0.95）后才允许内部滚动看更多表情。
      final atTop =
          _heightFactor >= MessageToolPanel.maxHeightFactor - 0.001;
      return SizedBox(
        height: targetHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onHandleDrag,
          onVerticalDragEnd: _onHandleDragEnd,
          child: Column(
            children: [
              _buildSheetHeader(context, colors),
              Expanded(
                child: EmojiPanel(
                  maxHeight: double.infinity,
                  // 对齐飞书稿：长按菜单里的表情面板只留内容（无标题栏/Tab 栏）
                  showTabBar: false,
                  backgroundColor: colors.background,
                  scrollPhysics: atTop
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  onEmojiSelected: (emoji) {
                    widget.onClose();
                    widget.actions.onReaction?.call(widget.message, emoji);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 工具面板：抽屉式高度——内容多高就多高，只有内容超过目标高度时才滚动，
    // 因此往上拖到内容刚好露完为止，底部不会留空白。
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: targetHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSheetHeader(context, colors),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                key: const ValueKey('message_tool_menu_content'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._buildMenuView(context, colors),
                  SizedBox(
                    height: 12 + MediaQuery.paddingOf(context).bottom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部可拖区域：把手（+ 表情界面的标题栏）整体可拖动改弹层高度
  Widget _buildSheetHeader(BuildContext context, AppColors colors) {
    return GestureDetector(
      key: const ValueKey('message_tool_sheet_header'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onHandleDrag,
      onVerticalDragEnd: _onHandleDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 22,
            alignment: Alignment.center,
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 拖把手：按拖动位移改弹层高度（拖动结束吸附到近端档位）
  void _onHandleDrag(DragUpdateDetails details) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (screenHeight <= 0) return;
    setState(() {
      _heightFactor = (_heightFactor - details.delta.dy / screenHeight).clamp(
        MessageToolPanel.minHeightFactor,
        MessageToolPanel.maxHeightFactor,
      );
    });
  }

  void _onHandleDragEnd(DragEndDetails details) {
    // 已经拉到最小还继续往下拖 → 关闭面板
    final draggingDown = (details.primaryVelocity ?? 0) > 0;
    if (draggingDown &&
        _heightFactor <= MessageToolPanel.minHeightFactor + 0.02) {
      widget.onClose();
      return;
    }
    // 吸附到最近档位：小窗 / 首屏一半 / 接近全屏
    const stops = [
      MessageToolPanel.minHeightFactor,
      MessageToolPanel.initialHeightFactor,
      MessageToolPanel.maxHeightFactor,
    ];
    final target = stops.reduce(
      (a, b) => (_heightFactor - a).abs() <= (_heightFactor - b).abs()
          ? a
          : b,
    );
    setState(() => _heightFactor = target);
  }

  /// 面板主体（对齐飞书稿）：
  /// ① 快捷表情行 ② 四宫格（回复/转发/创建话题/复制）
  /// ③ 撤回/多选 ④ 标记/Pin/置顶消息/复制消息链接/翻译/搜索/删除 ⑤ 添加任务/导出到文档
  List<Widget> _buildMenuView(BuildContext context, AppColors colors) {
    return [
      _buildReactionRow(colors),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            for (final action in _primaryActions())
              Expanded(child: _MessageToolTile(action: action)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _buildCard(_firstGroupActions()),
      if (_secondGroupActions().isNotEmpty) ...[
        const SizedBox(height: 8),
        _buildCard(_secondGroupActions()),
      ],
      const SizedBox(height: 8),
      _buildCard(_thirdGroupActions()),
    ];
  }

  /// 顶部表情行：6 个图标 + 「⋯」（点开完整表情界面）
  Widget _buildReactionRow(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Row(
        children: [
          for (final emoji in kMessageQuickReactions)
            Expanded(
              child: _QuickReactionButton(
                emoji: emoji,
                selected: widget.reactions.contains(emoji),
                onTap: () {
                  widget.onClose();
                  widget.actions.onReaction?.call(widget.message, emoji);
                },
              ),
            ),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.more_horiz),
              tooltip: '更多表情',
              onPressed: _openEmojiView,
            ),
          ),
        ],
      ),
    );
  }

  /// 切到完整表情界面（对齐飞书稿）：只换内容，弹层高度保持不变
  void _openEmojiView() => setState(() => _emojiOpen = true);

  /// 分组卡片：白底圆角 + 行间细分割线
  Widget _buildCard(List<_MessageToolAction> actions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: context.appColors.divider.withValues(alpha: 0.6),
                ),
              _MessageToolRow(action: actions[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// 四宫格：回复 / 转发 / 创建话题 / 复制（稿子里的第一组）
  List<_MessageToolAction> _primaryActions() => [
    _MessageToolAction(
      icon: Icons.reply_rounded,
      label: '回复',
      onTap: () => _runAction(widget.actions.onQuote),
    ),
    _MessageToolAction(
      icon: Icons.forward_rounded,
      label: '转发',
      onTap: () => _runAction(widget.actions.onForward),
    ),
    _MessageToolAction(
      icon: Icons.chat_bubble_outline,
      label: '创建话题',
      onTap: () => _runAction((_) => _notSupported('创建话题')),
    ),
    _MessageToolAction(
      icon: Icons.copy_rounded,
      label: '复制',
      onTap: () => _runAction(widget.actions.onCopy),
    ),
  ];

  /// 撤回（不可撤回时置灰）+ 多选（+ 失败消息的重发）
  List<_MessageToolAction> _firstGroupActions() => [
    _MessageToolAction(
      icon: Icons.undo_rounded,
      label: '撤回',
      enabled: _canRevoke,
      onTap: () => _runAction(widget.actions.onRevoke),
    ),
    if (widget.actions.onMultiSelect != null)
      _MessageToolAction(
        icon: Icons.library_add_check_outlined,
        label: '多选',
        onTap: () {
          widget.onClose();
          widget.actions.onMultiSelect!();
        },
      ),
    if (_isFromMe &&
        widget.message.status == 3 &&
        widget.actions.onResend != null)
      _MessageToolAction(
        icon: Icons.refresh_rounded,
        label: '重发',
        onTap: () => _runAction(widget.actions.onResend!),
      ),
  ];

  /// 标记 / Pin / 置顶消息 / 复制消息链接 / 翻译 / 飞书内搜索 / 网页搜索 / 删除
  List<_MessageToolAction> _secondGroupActions() => [
    _MessageToolAction(
      icon: Icons.flag_outlined,
      label: '标记',
      onTap: () => _runAction((_) => _notSupported('标记')),
    ),
    _MessageToolAction(
      icon: Icons.push_pin_outlined,
      label: 'Pin',
      onTap: () => _runAction((_) => _notSupported('Pin')),
    ),
    if (widget.actions.onPin != null)
      _MessageToolAction(
        icon: Icons.vertical_align_top_rounded,
        label: '置顶消息',
        onTap: () {
          widget.onClose();
          widget.actions.onPin!(widget.message);
        },
      ),
    _MessageToolAction(
      icon: Icons.link,
      label: '复制消息链接',
      onTap: () => _runAction((_) => _notSupported('复制消息链接')),
    ),
    _MessageToolAction(
      icon: Icons.translate,
      label: '翻译',
      onTap: () => _runAction((_) => _notSupported('翻译')),
    ),
    _MessageToolAction(
      icon: Icons.search,
      label: '飞书内搜索',
      onTap: () => _runAction((_) => _notSupported('飞书内搜索')),
    ),
    _MessageToolAction(
      icon: Icons.public,
      label: '网页搜索',
      onTap: () => _runAction((_) => _notSupported('网页搜索')),
    ),
    _MessageToolAction(
      icon: Icons.delete_outline_rounded,
      label: '删除',
      isDestructive: true,
      onTap: _confirmDelete,
    ),
  ];

  /// 添加任务 / 导出到文档
  List<_MessageToolAction> _thirdGroupActions() => [
    _MessageToolAction(
      icon: Icons.done_all_rounded,
      label: '添加任务',
      onTap: () => _runAction((_) => _notSupported('添加任务')),
    ),
    _MessageToolAction(
      icon: Icons.description_outlined,
      label: '导出到文档',
      onTap: () => _runAction((_) => _notSupported('导出到文档')),
    ),
  ];

  /// 未开放功能占位提示（与设置页一致）
  void _notSupported(String label) {
    ScaffoldMessenger.of(widget.rootContext).showSnackBar(
      SnackBar(
        content: Text('「$label」暂未开放'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _runAction(void Function(ChatMessage message) action) {
    widget.onClose();
    action(widget.message);
  }

  void _confirmDelete() {
    widget.onClose();
    showDialog<void>(
      context: widget.rootContext,
      builder: (ctx) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.actions.onDelete(widget.message);
            },
            child: Text('删除', style: TextStyle(color: ctx.appColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _QuickReactionButton extends StatelessWidget {
  const _QuickReactionButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              )
            : null,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _MessageToolAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool enabled;

  const _MessageToolAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });
}

class _MessageToolTile extends StatelessWidget {
  const _MessageToolTile({required this.action});

  final _MessageToolAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = !action.enabled
        ? colors.textSecondary.withValues(alpha: 0.5)
        : action.isDestructive
        ? colors.danger
        : colors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: action.enabled ? action.onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分组卡片里的一行：图标 + 文案（左对齐，整行可点；不可用时置灰）
class _MessageToolRow extends StatelessWidget {
  const _MessageToolRow({required this.action});

  final _MessageToolAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = !action.enabled
        ? colors.textSecondary.withValues(alpha: 0.5)
        : action.isDestructive
        ? colors.danger
        : colors.textPrimary;
    return InkWell(
      onTap: action.enabled ? action.onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(action.icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(action.label, style: TextStyle(fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}
