import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router/app_router.dart';
import '../services/app_lock_service.dart';
import '../services/local_notification_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';

/// 账号设置页：全局免打扰、本地通知、应用锁、生物识别、语言、关于。
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  String _localeCode = 'zh';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final appLock = await AppLockService.instance.isEnabled();
    final biometric = await AppLockService.instance.isBiometricEnabled();
    final notifications = await LocalNotificationService.instance.isEnabled();
    final localeCode = LocaleService.instance.locale.value?.languageCode == 'en'
        ? 'en'
        : 'zh';
    if (mounted) {
      setState(() {
        _appLockEnabled = appLock;
        _biometricEnabled = biometric;
        _notificationsEnabled = notifications;
        _localeCode = localeCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).profile;
    final globalMute = profile?.globalRecvMsgOpt == 1;
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
          _buildSection(
            children: [
              SwitchListTile(
                title: const Text('全局消息免打扰'),
                subtitle: const Text('开启后不再接收任何新消息提醒'),
                value: globalMute,
                onChanged: client == null
                    ? null
                    : (v) async {
                        try {
                          await client.setGlobalMsgRecvOpt(
                            globalRecvOpt: v ? 1 : 0,
                          );
                          await ref
                              .read(messageServiceProvider.notifier)
                              .refreshLoginUserProfile();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('设置失败: $e')));
                          }
                        }
                      },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('新消息本地通知'),
                subtitle: const Text('后台收到新消息时显示系统通知'),
                value: _notificationsEnabled,
                onChanged: (v) async {
                  setState(() => _notificationsEnabled = v);
                  await LocalNotificationService.instance.setEnabled(v);
                },
              ),
            ],
          ),
          _buildSection(
            children: [
              SwitchListTile(
                title: const Text('应用锁'),
                subtitle: const Text('重新打开应用时输入 PIN 解锁'),
                value: _appLockEnabled,
                onChanged: _toggleAppLock,
              ),
              if (_appLockEnabled) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('生物识别解锁'),
                  subtitle: const Text('使用指纹或面容 ID 解锁'),
                  value: _biometricEnabled,
                  onChanged: _toggleBiometric,
                ),
              ],
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: const Text('修改密码'),
                subtitle: const Text('当前服务暂未开放修改密码'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showPasswordUnavailable,
              ),
            ],
          ),
          _buildSection(
            children: [
              ListTile(
                title: const Text('语言'),
                trailing: Text(
                  _localeCode == 'en' ? 'English' : '简体中文',
                  style: const TextStyle(color: AppTheme.textSecondaryColor),
                ),
                onTap: _changeLanguage,
              ),
            ],
          ),
          _buildSection(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于我们'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showAbout,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: children),
      ),
    );
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      final pin = await _askPin();
      if (pin == null) return;
      await AppLockService.instance.savePin(pin);
      await AppLockService.instance.setEnabled(true);
      setState(() => _appLockEnabled = true);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('关闭应用锁'),
          content: const Text('关闭后下次打开应用不再需要 PIN 解锁。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await AppLockService.instance.setEnabled(false);
      setState(() {
        _appLockEnabled = false;
        _biometricEnabled = false;
      });
    }
  }

  Future<String?> _askPin() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设置应用锁 PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: '请输入 4-6 位数字',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length < 4 || value.length > 6) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(const SnackBar(content: Text('PIN 长度需要 4-6 位')));
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      final canUse = await AppLockService.instance.canUseBiometrics();
      if (!canUse) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前设备不支持生物识别')));
        }
        return;
      }
      final ok = await AppLockService.instance.authenticateWithBiometrics();
      if (!ok) return;
      await AppLockService.instance.setBiometricEnabled(true);
      setState(() => _biometricEnabled = true);
    } else {
      await AppLockService.instance.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
    }
  }

  Future<void> _changeLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('简体中文'),
              trailing: _localeCode == 'zh'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop('zh'),
            ),
            ListTile(
              title: const Text('English'),
              trailing: _localeCode == 'en'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop('en'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await LocaleService.instance.setLocale(selected);
    if (mounted) {
      setState(() => _localeCode = selected);
    }
  }

  void _showPasswordUnavailable() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改密码'),
        content: const Text('当前 OpenIM 服务未提供修改密码接口，服务端支持后可以接入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关于我们'),
        content: const Text('OpenIM Flutter Rust 示例应用\n版本 1.0.0'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
