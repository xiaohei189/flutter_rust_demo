import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/account_settings_provider.dart';
import '../providers/user_profile_provider.dart';
import '../view_models/account_settings_view_model.dart';

/// 账号设置页：全局免打扰、本地通知、应用锁、生物识别、语言、关于。
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  late final AccountSettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(accountSettingsViewModelProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_viewModel.load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = ref.watch(accountSettingsViewModelProvider);
    final profile = ref.watch(userProfileViewProvider).profile;
    final globalMute = profile?.globalRecvMsgOpt == 1;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.accountSettingsTitle ?? '账号设置',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            children: [
              SwitchListTile(
                title: const Text('全局消息免打扰'),
                subtitle: const Text('开启后不再接收任何新消息提醒'),
                value: globalMute,
                onChanged: _setGlobalMute,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('新消息本地通知'),
                subtitle: const Text('后台收到新消息时显示系统通知'),
                value: settings.notificationsEnabled,
                onChanged: _setNotificationsEnabled,
              ),
            ],
          ),
          _buildSection(
            context,
            children: [
              SwitchListTile(
                title: const Text('应用锁'),
                subtitle: const Text('重新打开应用时输入 PIN 解锁'),
                value: settings.appLockEnabled,
                onChanged: _toggleAppLock,
              ),
              if (settings.appLockEnabled) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('生物识别解锁'),
                  subtitle: const Text('使用指纹或面容 ID 解锁'),
                  value: settings.biometricEnabled,
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
            context,
            children: [
              ListTile(
                title: const Text('语言'),
                trailing: Text(
                  settings.localeCode == 'en' ? 'English' : '简体中文',
                  style: TextStyle(color: colors.textSecondary),
                ),
                onTap: _changeLanguage,
              ),
            ],
          ),
          _buildSection(
            context,
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

  Widget _buildSection(BuildContext context, {required List<Widget> children}) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: children),
      ),
    );
  }

  Future<void> _setGlobalMute(bool value) async {
    final ok = await _viewModel.setGlobalMute(value);
    if (mounted && !ok) {
      _showError(_viewModel.currentState.error ?? '设置失败');
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final ok = await _viewModel.setNotificationsEnabled(value);
    if (mounted && !ok) {
      _showError(_viewModel.currentState.error ?? '设置失败');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      final pin = await _askPin();
      if (pin == null) return;
      final ok = await _viewModel.enableAppLock(pin);
      if (mounted && !ok) {
        _showError(_viewModel.currentState.error ?? '开启应用锁失败');
      }
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
      final ok = await _viewModel.disableAppLock();
      if (mounted && !ok) {
        _showError(_viewModel.currentState.error ?? '关闭应用锁失败');
      }
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
      final ok = await _viewModel.enableBiometric();
      if (mounted && !ok) {
        _showError(_viewModel.currentState.error ?? '开启生物识别失败');
      }
    } else {
      final ok = await _viewModel.disableBiometric();
      if (mounted && !ok) {
        _showError(_viewModel.currentState.error ?? '关闭生物识别失败');
      }
    }
  }

  Future<void> _changeLanguage() async {
    final colors = context.appColors;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('简体中文'),
              trailing: _viewModel.currentState.localeCode == 'zh'
                  ? Icon(Icons.check, color: colors.primary)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop('zh'),
            ),
            ListTile(
              title: const Text('English'),
              trailing: _viewModel.currentState.localeCode == 'en'
                  ? Icon(Icons.check, color: colors.primary)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop('en'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _viewModel.setLocale(selected);
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
