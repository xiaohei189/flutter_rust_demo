import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_demo/domain/extensions/message_ext.dart';
import 'package:flutter_rust_demo/generated/rust/model/message.dart'
    show MessageInfo;
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

/// 消息操作回调
class MessageActions {
  final void Function(MessageInfo message) onCopy;
  final void Function(MessageInfo message) onRevoke;
  final void Function(MessageInfo message) onDelete;
  final void Function(MessageInfo message) onForward;
  final void Function(MessageInfo message) onQuote;
  final VoidCallback? onMultiSelect;
  final void Function(MessageInfo message)? onResend;

  const MessageActions({
    required this.onCopy,
    required this.onRevoke,
    required this.onDelete,
    required this.onForward,
    required this.onQuote,
    this.onMultiSelect,
    this.onResend,
  });
}

/// 显示消息长按操作菜单
void showMessageActionMenu(
  BuildContext context, {
  required MessageInfo message,
  required String currentUserId,
  required MessageActions actions,
}) {
  final isFromMe = message.sendId == currentUserId;
  final canRevoke =
      isFromMe && DateTime.now().difference(message.sendDateTime).inMinutes < 2;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MessageActionSheet(
      message: message,
      isFromMe: isFromMe,
      canRevoke: canRevoke,
      actions: actions,
    ),
  );
}

class _MessageActionSheet extends StatelessWidget {
  final MessageInfo message;
  final bool isFromMe;
  final bool canRevoke;
  final MessageActions actions;

  const _MessageActionSheet({
    required this.message,
    required this.isFromMe,
    required this.canRevoke,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: colors.cardShadow,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 操作项
            ..._buildActionItems(context),
            Divider(height: 1, color: colors.divider),
            // 取消按钮
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Center(
                  child: Text(
                    '取消',
                    style: TextStyle(fontSize: 16, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionItems(BuildContext context) {
    final items = <_ActionItem>[
      _ActionItem(
        icon: Icons.copy_rounded,
        label: '复制',
        onTap: () => _doCopy(context),
      ),
      _ActionItem(
        icon: Icons.reply_rounded,
        label: '引用',
        onTap: () => _doAction(context, actions.onQuote),
      ),
      _ActionItem(
        icon: Icons.forward_rounded,
        label: '转发',
        onTap: () => _doAction(context, actions.onForward),
      ),
    ];

    if (actions.onMultiSelect != null) {
      items.add(
        _ActionItem(
          icon: Icons.library_add_check_outlined,
          label: '多选',
          onTap: () {
            Navigator.of(context).pop();
            actions.onMultiSelect!();
          },
        ),
      );
    }

    if (canRevoke) {
      items.add(
        _ActionItem(
          icon: Icons.undo_rounded,
          label: '撤回',
          onTap: () => _doAction(context, actions.onRevoke),
        ),
      );
    }

    if (isFromMe && message.status == 3 && actions.onResend != null) {
      items.add(
        _ActionItem(
          icon: Icons.refresh_rounded,
          label: '重发',
          onTap: () => _doAction(context, actions.onResend!),
        ),
      );
    }

    items.add(
      _ActionItem(
        icon: Icons.delete_outline_rounded,
        label: '删除',
        isDestructive: true,
        onTap: () => _confirmDelete(context),
      ),
    );

    return items.map((item) => _buildActionItem(context, item)).toList();
  }

  Widget _buildActionItem(BuildContext context, _ActionItem item) {
    final colors = context.appColors;
    return InkWell(
      onTap: item.onTap,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              item.icon,
              size: 22,
              color: item.isDestructive ? colors.danger : colors.textPrimary,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15,
                color: item.isDestructive ? colors.danger : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _doCopy(BuildContext context) {
    final text = message.content;
    Clipboard.setData(ClipboardData(text: text));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  }

  void _doAction(BuildContext context, void Function(MessageInfo) action) {
    Navigator.of(context).pop();
    action(message);
  }

  void _confirmDelete(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
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
              actions.onDelete(message);
            },
            child: Text(
              '删除',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}
