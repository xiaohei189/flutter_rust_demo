import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/chat_list_provider.dart';
import '../../providers/conversation_folder_provider.dart';
import '../../view_models/chat_list_view_model.dart';

/// 会话列表页的对话框与扫码处理：分组新建/删除/移动、全部归档、扫码跳转。
/// 与 [ChatMediaActions] 一样由页面持有，方法按需接收 [BuildContext]。
class ChatListDialogs {
  ChatListDialogs({required this.ref, required this.viewModel});

  final WidgetRef ref;
  final ChatListViewModel viewModel;

  Future<void> showCreateFolderDialog(BuildContext context) async {
    final name = await _promptFolderName(context);
    if (name == null) return;
    await ref.read(conversationFoldersProvider.notifier).createFolder(name);
  }

  Future<void> showDeleteFolderDialog(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定删除分组「$name」吗？会话不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(conversationFoldersProvider.notifier).removeFolder(name);
    if (ref.read(chatListViewModelProvider).activeFolder == name) {
      viewModel.setFolder(null);
    }
  }

  /// 选择移动到的分组；取消返回 null。
  Future<String?> pickFolder(BuildContext context) async {
    final folders = ref.read(conversationFoldersProvider);
    final names = folders.keys.toList();
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到分组'),
        children: [
          for (final name in names)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(name),
              child: Text(name),
            ),
          if (names.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('还没有分组，先新建一个吧', style: TextStyle(fontSize: 13)),
            ),
          SimpleDialogOption(
            onPressed: () async {
              final name = await _promptFolderName(ctx);
              if (name == null) return;
              await ref
                  .read(conversationFoldersProvider.notifier)
                  .createFolder(name);
              if (ctx.mounted) Navigator.of(ctx).pop(name);
            },
            child: const Text('新建分组…'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptFolderName(BuildContext ctx) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分组名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> confirmArchiveAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全部归档'),
        content: const Text('确定归档所有会话吗？可在「归档」分组中恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '归档',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await viewModel.archiveAllConversations();
    }
  }

  /// 处理扫码结果：URL 提示复制，群/用户 ID 跳转对应资料页。
  void handleScanResult(BuildContext context, String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      _showUnsupportedUrlDialog(context, raw);
      return;
    }
    if (raw.startsWith('g_') || raw.startsWith('sg_')) {
      AppRouter.goToGroupInfoById(context, raw);
    } else {
      AppRouter.goToUserProfile(context, userId: raw);
    }
  }

  void _showUnsupportedUrlDialog(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫描到链接'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制链接'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('复制链接'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
