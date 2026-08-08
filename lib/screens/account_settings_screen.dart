import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 账号设置页：目前提供全局消息免打扰开关。
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _globalMute = false;

  @override
  Widget build(BuildContext context) {
    final client = ref.read(messageServiceProvider.notifier).client;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('账号设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            child: SwitchListTile(
              title: const Text('全局消息免打扰'),
              subtitle: const Text('开启后不再接收任何新消息提醒'),
              value: _globalMute,
              onChanged: client == null
                  ? null
                  : (v) async {
                      setState(() => _globalMute = v);
                      try {
                        await client.setGlobalMsgRecvOpt(
                          globalRecvOpt: v ? 1 : 0,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(v ? '已开启全局免打扰' : '已关闭全局免打扰'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => _globalMute = !v);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('设置失败: $e')),
                          );
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
