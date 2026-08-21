import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../../../../router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/entry_tile.dart';

/// 发现页：提供我的二维码、帮助与反馈、关于我们等入口。
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileViewProvider).profile;
    final userId = profile?.userId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.discoverTitle ?? '发现'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          EntryTile(
            icon: Icons.qr_code_2,
            title: '我的二维码',
            onTap: userId.isEmpty
                ? null
                : () {
                    AppRouter.goToQrCode(
                      context,
                      title: '我的二维码',
                      data: userId,
                      subtitle: profile?.nickname,
                    );
                  },
          ),
          EntryTile(
            icon: Icons.headset_mic_outlined,
            title: '帮助与反馈',
            onTap: () => _showMessage(context, '帮助与反馈', '请描述你遇到的问题，我们会尽快处理。'),
          ),
          EntryTile(
            icon: Icons.info_outline,
            title: '关于我们',
            onTap: () => _showMessage(
              context,
              '关于我们',
              'OpenIM Flutter Rust 示例应用\n版本 1.0.0',
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
