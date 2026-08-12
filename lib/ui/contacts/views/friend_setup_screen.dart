import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/core/theme/app_theme.dart';
import '../providers/friend_setup_provider.dart';
import '../view_models/friend_setup_view_model.dart';

/// 好友设置页面
///
/// 从用户资料页面进入，提供以下设置项：
/// - 设置备注
/// - 消息免打扰
/// - 置顶聊天
/// - 加入黑名单
/// - 删除好友
class FriendSetupScreen extends ConsumerStatefulWidget {
  final String userId;

  const FriendSetupScreen({super.key, required this.userId});

  @override
  ConsumerState<FriendSetupScreen> createState() => _FriendSetupScreenState();
}

class _FriendSetupScreenState extends ConsumerState<FriendSetupScreen> {
  late final FriendSetupViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(friendSetupViewModelProvider(widget.userId).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_viewModel.load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(friendSetupViewModelProvider(widget.userId));
    return Scaffold(
      appBar: AppBar(title: const Text('好友设置'), elevation: 0),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),

                // 设置备注
                _buildSettingItem(
                  title: '设置备注',
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: context.appColors.textSecondary,
                  ),
                  onTap: _showRemarkDialog,
                ),

                const SizedBox(height: 12),

                // 消息免打扰
                _buildSwitchItem(
                  title: '消息免打扰',
                  value: settings.isMuted,
                  onChanged: _toggleMute,
                ),

                // 置顶聊天
                _buildSwitchItem(
                  title: '置顶聊天',
                  value: settings.isPinned,
                  onChanged: _togglePin,
                ),

                const SizedBox(height: 12),

                // 加入黑名单
                _buildSwitchItem(
                  title: '加入黑名单',
                  value: settings.isBlacklisted,
                  onChanged: _toggleBlacklist,
                  isDestructive: true,
                ),

                const SizedBox(height: 24),

                // 删除好友
                _buildDangerButton(title: '删除好友', onTap: _confirmDeleteFriend),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  /// 构建设置项
  Widget _buildSettingItem({
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isDestructive = false,
  }) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive
                    ? const Color(0xFFFF3B30)
                    : context.appColors.textPrimary,
              ),
            ),
            const Spacer(),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: isDestructive
                  ? const Color(0xFFFF3B30)
                  : context.appColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建危险操作按钮
  Widget _buildDangerButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// 显示设置备注对话框
  void _showRemarkDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注名称',
            hintStyle: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          textInputAction: TextInputAction.done,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.dispose();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final remark = controller.text.trim();
              controller.dispose();
              await _updateRemark(remark);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 更新备注
  Future<void> _updateRemark(String remark) async {
    final ok = await _viewModel.updateRemark(remark);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('备注已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '更新备注失败');
    }
  }

  /// 切换消息免打扰
  Future<void> _toggleMute(bool value) async {
    final ok = await _viewModel.setMuted(value);
    if (mounted && !ok) {
      _showError(_viewModel.currentState.error ?? '设置失败');
    }
  }

  /// 切换置顶聊天
  Future<void> _togglePin(bool value) async {
    final ok = await _viewModel.setPinned(value);
    if (mounted && !ok) {
      _showError(_viewModel.currentState.error ?? '设置失败');
    }
  }

  /// 切换黑名单
  Future<void> _toggleBlacklist(bool value) async {
    if (value) {
      // 加入黑名单前确认
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('加入黑名单'),
          content: const Text('加入黑名单后将不再收到对方的消息，确定继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '确定',
                style: TextStyle(color: Color(0xFFFF3B30)),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final ok = await _viewModel.setBlacklisted(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '已加入黑名单' : '已移出黑名单'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '操作失败');
    }
  }

  /// 确认删除好友
  Future<void> _confirmDeleteFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: const Text('删除后将移除该好友，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _viewModel.deleteFriend();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已删除好友'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.mounted) {
        context.pop();
      }
    } else {
      _showError(_viewModel.currentState.error ?? '删除失败');
    }
  }
}
