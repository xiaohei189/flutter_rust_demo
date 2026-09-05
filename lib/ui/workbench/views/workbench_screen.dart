import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/app_paths.dart';
import '../../../../router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../chat/providers/chat_list_provider.dart';
import '../../chat/providers/message_service_provider.dart';
import '../../chat/widgets/list/chat_list_dialogs.dart';
import '../../profile/providers/user_profile_provider.dart';

/// 工作台页（飞书风格）：常用功能应用入口 + 通知设置。
///
/// 承载原「+」菜单里的动作类功能（发起群聊/加群/添加好友/扫一扫/全部归档），
/// 以及全局免打扰开关；个人/账号类功能统一在头像抽屉。
class WorkbenchScreen extends ConsumerWidget {
  const WorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final profile = ref.watch(userProfileViewProvider).profile;
    final muted = profile?.globalRecvMsgOpt == 1;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.workbenchTitle ?? '工作台'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildAppGrid(context, ref),
          const SizedBox(height: 12),
          Container(
            color: colors.surface,
            child: SwitchListTile(
              secondary: Icon(
                Icons.notifications_off_outlined,
                color: colors.textPrimary,
              ),
              title: const Text('全局免打扰'),
              subtitle: const Text('开启后不再接收任何新消息提醒'),
              value: muted,
              onChanged: (value) => _toggleGlobalMute(context, ref, muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppGrid(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final apps = <({IconData icon, Color color, String label, VoidCallback onTap})>[
      (
        icon: Icons.group_add_outlined,
        color: const Color(0xFF3370FF),
        label: '发起群聊',
        onTap: () => AppRouter.goToCreateGroup(context),
      ),
      (
        icon: Icons.person_add_alt_1,
        color: const Color(0xFF07C160),
        label: '添加好友',
        onTap: () => AppRouter.goToAddContact(context),
      ),
      (
        icon: Icons.group_outlined,
        color: const Color(0xFF9B5DE5),
        label: '加群',
        onTap: () => AppRouter.goToSearch(context),
      ),
      (
        icon: Icons.qr_code_scanner_outlined,
        color: const Color(0xFFFF8F1F),
        label: '扫一扫',
        onTap: () => _handleScan(context, ref),
      ),
      (
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF00B8A9),
        label: '全部归档',
        onTap: () => _handleArchiveAll(context, ref),
      ),
    ];

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        childAspectRatio: 0.92,
        children: [
          for (final app in apps)
            InkWell(
              onTap: app.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 图标去掉底色块，纯彩色图标，与飞书风格一致。
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(app.icon, size: 28, color: app.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.label,
                    style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleScan(BuildContext context, WidgetRef ref) async {
    final raw = await context.push<String>(AppPaths.scan);
    if (raw == null || !context.mounted) return;
    final dialogs = _dialogs(ref);
    dialogs.handleScanResult(context, raw);
  }

  Future<void> _handleArchiveAll(BuildContext context, WidgetRef ref) async {
    await _dialogs(ref).confirmArchiveAll(context);
  }

  ChatListDialogs _dialogs(WidgetRef ref) => ChatListDialogs(
        ref: ref,
        viewModel: ref.read(chatListViewModelProvider.notifier),
      );

  Future<void> _toggleGlobalMute(
    BuildContext context,
    WidgetRef ref,
    bool muted,
  ) async {
    try {
      await ref
          .read(messageRepositoryProvider)
          .setGlobalMsgRecvOpt(globalRecvOpt: muted ? 0 : 1);
      await ref.read(messageServiceProvider.notifier).refreshLoginUserProfile();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(muted ? '关闭全局免打扰失败' : '开启全局免打扰失败'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
