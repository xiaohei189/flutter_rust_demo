import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/providers.dart';
import '../../../../ui/features/profile/views/qr_code_screen.dart';
import '../../../../theme/app_theme.dart';

/// 发现页：提供我的二维码、帮助与反馈、关于我们等入口。
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).profile;
    final userId = profile?.userId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _EntryTile(
            icon: Icons.qr_code_2,
            title: '我的二维码',
            onTap: userId.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QrCodeScreen(
                          title: '我的二维码',
                          data: userId,
                          subtitle: profile?.nickname,
                        ),
                      ),
                    );
                  },
          ),
          _EntryTile(
            icon: Icons.headset_mic_outlined,
            title: '帮助与反馈',
            onTap: () => _showMessage(context, '帮助与反馈', '请描述你遇到的问题，我们会尽快处理。'),
          ),
          _EntryTile(
            icon: Icons.info_outline,
            title: '关于我们',
            onTap: () => _showMessage(context, '关于我们', 'OpenIM Flutter Rust 示例应用\n版本 1.0.0'),
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.white,
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }
}
