import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/core/theme/app_theme.dart';
import '../providers/conversation_folder_provider.dart';

/// 自定义分组管理：新建 / 重命名 / 拖动排序 / 删除。
///
/// 分组数据只存本地（`ConversationFolderStore`），不参与服务端同步。
class ConversationFolderManageScreen extends ConsumerWidget {
  const ConversationFolderManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final folders = ref.watch(conversationFoldersProvider);
    final names = folders.keys.toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('分组管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建分组',
            onPressed: () => _createFolder(context, ref),
          ),
        ],
      ),
      body: names.isEmpty
          ? _buildEmpty(context, ref)
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: names.length,
              // 长按拖动排序；顺序同样落在本地存储里。
              buildDefaultDragHandles: true,
              onReorderItem: (oldIndex, newIndex) {
                final next = List<String>.from(names);
                final moved = next.removeAt(oldIndex);
                next.insert(newIndex, moved);
                ref
                    .read(conversationFoldersProvider.notifier)
                    .reorderFolders(next);
              },
              itemBuilder: (context, index) {
                final name = names[index];
                return ListTile(
                  key: ValueKey<String>(name),
                  leading: Icon(
                    Icons.folder_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(name),
                  subtitle: Text(
                    '${folders[name]?.length ?? 0} 个会话',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.drive_file_rename_outline,
                            size: 20),
                        tooltip: '重命名',
                        onPressed: () => _renameFolder(context, ref, name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: '删除',
                        onPressed: () => _deleteFolder(context, ref, name),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.create_new_folder_outlined,
            size: 64,
            color: colors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有分组',
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '分组只保存在本机，用于把会话归到自定义分类里',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _createFolder(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建分组'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    // 先取 messenger：弹窗返回后不再依赖 BuildContext。
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptName(context, title: '新建分组');
    if (name == null) return;
    final notifier = ref.read(conversationFoldersProvider.notifier);
    if (ref.read(conversationFoldersProvider).containsKey(name)) {
      _showMessage(messenger, '分组「$name」已存在');
      return;
    }
    await notifier.createFolder(name);
  }

  Future<void> _renameFolder(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptName(
      context,
      title: '重命名分组',
      initialValue: current,
    );
    if (name == null || name == current) return;
    final ok = await ref
        .read(conversationFoldersProvider.notifier)
        .renameFolder(current, name);
    if (!ok) _showMessage(messenger, '重命名失败：名称已存在');
  }

  Future<void> _deleteFolder(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
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
  }

  /// 分组名输入弹窗；取消返回 null。
  ///
  /// 用 [TextFormField] 自带的控制器，不手动持有/释放：弹窗返回时路由仍在退场，
  /// 此时 dispose 控制器会让退场中的 TextField 引用到已销毁对象（真机触发过
  /// framework 的 `_dependents.isEmpty` 断言崩溃）。
  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) async {
    var input = initialValue;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '分组名称'),
          onChanged: (value) => input = value,
          onFieldSubmitted: (value) => Navigator.of(dialogCtx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(input.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return (result == null || result.isEmpty) ? null : result;
  }

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}
