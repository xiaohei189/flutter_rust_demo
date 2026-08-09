import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/providers.dart';
import '../../../../src/rust/constant/enums.dart' show SessionType;
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_logger.dart';

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
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isBlacklisted = false;
  bool _isLoading = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final client =
          ref.read(messageServiceProvider.notifier).client;
      if (client == null) return;

      // 获取单聊会话 ID
      final convId = await client.getConversationIdBySessionType(
        sourceId: widget.userId,
        sessionType: SessionType.singleChat,
      );
      _conversationId = convId;

      // 从会话列表中查找该会话的设置
      final conversations = ref.read(conversationsProvider);
      final conv = conversations.where(
        (c) => c.conversationId == convId,
      ).firstOrNull;

      if (conv != null) {
        _isMuted = conv.recvMsgOpt == 1;
    _isPinned = conv.isPinned;
      }

      // 检查黑名单
      _isBlacklisted = await client.isInBlacklist(userId: widget.userId);
    } catch (e) {
      appLog.e('[FriendSetupScreen] 加载好友设置失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友设置'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),

                // 设置备注
                _buildSettingItem(
                  title: '设置备注',
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  onTap: _showRemarkDialog,
                ),

                const SizedBox(height: 12),

                // 消息免打扰
                _buildSwitchItem(
                  title: '消息免打扰',
                  value: _isMuted,
                  onChanged: _toggleMute,
                ),

                // 置顶聊天
                _buildSwitchItem(
                  title: '置顶聊天',
                  value: _isPinned,
                  onChanged: _togglePin,
                ),

                const SizedBox(height: 12),

                // 加入黑名单
                _buildSwitchItem(
                  title: '加入黑名单',
                  value: _isBlacklisted,
                  onChanged: _toggleBlacklist,
                  isDestructive: true,
                ),

                const SizedBox(height: 24),

                // 删除好友
                _buildDangerButton(
                  title: '删除好友',
                  onTap: _confirmDeleteFriend,
                ),

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
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimaryColor,
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
                    : AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: isDestructive
                  ? const Color(0xFFFF3B30)
                  : AppTheme.primaryColor,
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
            hintStyle: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
    try {
      await ref.read(friendRepositoryProvider).updateFriends(
        widget.userId,
        remark: remark,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('备注已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      appLog.e('[FriendSetupScreen] 更新备注失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新备注失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 切换消息免打扰
  Future<void> _toggleMute(bool value) async {
    final client =
        ref.read(messageServiceProvider.notifier).client;
    if (client == null || _conversationId == null) return;

    try {
      await client.setConversation(
        conversationId: _conversationId!,
        recvMsgOpt: value ? 1 : 0,
      );
      setState(() => _isMuted = value);
    } catch (e) {
      appLog.e('[FriendSetupScreen] 设置消息免打扰失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 切换置顶聊天
  Future<void> _togglePin(bool value) async {
    final client =
        ref.read(messageServiceProvider.notifier).client;
    if (client == null || _conversationId == null) return;

    try {
      await client.setConversationPinned(
        conversationId: _conversationId!,
        isPinned: value,
      );
      setState(() => _isPinned = value);
    } catch (e) {
      appLog.e('[FriendSetupScreen] 设置置顶聊天失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

    final ok = value
        ? await ref.read(blackListProvider.notifier).add(widget.userId)
        : await ref.read(blackListProvider.notifier).remove(widget.userId);
    if (!mounted) return;
    if (ok) {
      setState(() => _isBlacklisted = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '已加入黑名单' : '已移出黑名单'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败')));
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
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref
        .read(friendListProvider.notifier)
        .deleteFriend(widget.userId);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败')));
    }
  }
}
