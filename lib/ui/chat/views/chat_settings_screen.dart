import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../view_models/chat_settings_view_model.dart';
import '../widgets/settings_components.dart';

/// 聊天设置页面：单聊 / 群聊 分别展示不同内容
class ChatSettingsScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatSettingsScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  late final ChatSettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(
      chatSettingsViewModelProvider(widget.conversationId).notifier,
    );
    final conversation = _viewModel.conversation;
    if (conversation != null) {
      _viewModel.initialize(conversation);
    }
    if (_viewModel.isGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_viewModel.loadGroupMembers());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      chatSettingsViewModelProvider(widget.conversationId),
    );
    final conversation = _viewModel.conversation;
    final isGroup = _viewModel.isGroup;

    if (conversation == null) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          title: const Text('设置'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => AppRouter.goBack(context),
          ),
        ),
        body: const Center(child: Text('会话不存在')),
      );
    }

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ---- 顶部：成员区域 ----
          SettingsCard(
            children: [
              if (isGroup) ..._buildGroupHeader() else ..._buildSingleHeader(),
            ],
          ),

          // ---- 群成员（仅群聊） ----
          if (isGroup) ...[
            const SizedBox(height: 8),
            SettingsCard(children: _buildGroupMembers()),
          ],

          // ---- 应用 ----
          if (isGroup) ...[
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                const SettingsSectionTitle(title: '群应用'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      _buildAppIcon(
                        Icons.campaign_outlined,
                        '群公告',
                        context.appColors.primary,
                        onTap: _editGroupAnnouncement,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                SettingsNavRow(title: '群昵称', onTap: _editGroupNickname),
              ],
            ),
          ],

          // ---- 开关设置区 ----
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsSwitchRow(
                title: '消息免打扰',
                value: settings.muteNotification,
                onChanged: _setMuteNotification,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsSwitchRow(
                title: '置顶会话',
                value: settings.pinChat,
                onChanged: _setPinChat,
              ),
              if (!isGroup) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SettingsSwitchRow(
                  title: '私聊（阅后即焚）',
                  value: settings.privateChat,
                  onChanged: _setPrivateChat,
                ),
              ],
            ],
          ),

          // ---- 清空聊天记录 ----
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsNavRow(title: '清空聊天记录', onTap: _handleClearChatHistory),
            ],
          ),

          // ---- 退出群组（仅群聊） ----
          if (isGroup) ...[
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                InkWell(
                  onTap: () => _handleQuitGroup(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        '退出群组',
                        style: TextStyle(
                          fontSize: 15,
                          color: context.appColors.danger,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ---- 会话 ID ----
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: conversation.conversationId),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制会话 ID'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '会话 ID: ${conversation.conversationId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_outlined,
                    size: 12,
                    color: context.appColors.textSecondary.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildSingleHeader() {
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(user: _viewModel.chatUser, radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _viewModel.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '在线',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: context.appColors.textSecondary,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildGroupHeader() {
    final memberCount = ref
        .watch(groupMemberProvider(_viewModel.groupId))
        .members
        .length;

    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(user: _viewModel.chatUser, radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _viewModel.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    memberCount > 0 ? '群聊 · $memberCount 人' : '群聊',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: context.appColors.textSecondary,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildGroupMembers() {
    final memberState = ref.watch(groupMemberProvider(_viewModel.groupId));
    final members = memberState.members;

    return [
      SettingsSectionTitle(
        title: '群成员${memberState.isLoading ? '' : ' (${members.length})'}',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final member in members) RealMemberAvatar(member: member),
            AddMemberButton(onTap: _showInviteMemberDialog),
          ],
        ),
      ),
    ];
  }

  Widget _buildAppIcon(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMuteNotification(bool value) async {
    await _viewModel.setMuteNotification(value);
    if (mounted) _showError(_viewModel.currentState.error);
  }

  Future<void> _setPinChat(bool value) async {
    await _viewModel.setPinChat(value);
    if (mounted) _showError(_viewModel.currentState.error);
  }

  Future<void> _setPrivateChat(bool value) async {
    await _viewModel.setPrivateChat(value);
    if (mounted) _showError(_viewModel.currentState.error);
  }

  void _showError(String? message) {
    if (message == null || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handleQuitGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出群组'),
        content: const Text('确定要退出该群组吗？退出后将无法接收群消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '退出',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _viewModel.quitGroup();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已退出群组'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      _showError(_viewModel.currentState.error ?? '退出群组失败');
    }
  }

  /// 清空聊天记录
  Future<void> _handleClearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空该会话的所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '清空',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _viewModel.clearHistory();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('聊天记录已清空'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '清空聊天记录失败');
    }
  }

  /// 修改自己在群里的昵称
  Future<void> _editGroupNickname() async {
    final controller = TextEditingController();
    final nickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改群昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入群昵称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nickname == null || nickname.isEmpty) return;

    final ok = await _viewModel.updateGroupNickname(nickname);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群昵称已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '更新失败');
    }
  }

  /// 编辑群公告
  Future<void> _editGroupAnnouncement() async {
    final current = await _viewModel.currentGroupAnnouncement();
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑群公告'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '请输入群公告',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;

    final ok = await _viewModel.updateGroupAnnouncement(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群公告已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '群公告更新失败');
    }
  }

  /// 显示邀请成员对话框
  void _showInviteMemberDialog() {
    final selectedIds = <String>[];
    unawaited(_viewModel.loadInviteFriends());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Consumer(
                  builder: (context, ref, _) {
                    final friendState = ref.watch(friendListProvider);

                    return Column(
                      children: [
                        // 标题栏
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '邀请成员',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton(
                                onPressed: selectedIds.isEmpty
                                    ? null
                                    : () async {
                                        Navigator.of(context).pop();
                                        await _inviteMembers(selectedIds);
                                      },
                                child: Text(
                                  '确定 (${selectedIds.length})',
                                  style: TextStyle(
                                    color: selectedIds.isEmpty
                                        ? context.appColors.textSecondary
                                        : context.appColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 好友列表
                        Expanded(
                          child: friendState.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : friendState.friends.isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无好友',
                                    style: TextStyle(
                                      color: context.appColors.textSecondary,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: friendState.friends.length,
                                  itemBuilder: (context, index) {
                                    final friend = friendState.friends[index];
                                    final isSelected = selectedIds.contains(
                                      friend.userId,
                                    );

                                    return ListTile(
                                      leading: UserAvatar(
                                        user: User(
                                          id: friend.userId,
                                          name: friend.nickname,
                                          avatar: friend.faceUrl.isNotEmpty
                                              ? friend.faceUrl
                                              : null,
                                        ),
                                        radius: 20,
                                      ),
                                      title: Text(
                                        friend.remark.isNotEmpty
                                            ? friend.remark
                                            : friend.nickname,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        activeColor: context.appColors.primary,
                                        onChanged: (checked) {
                                          setSheetState(() {
                                            if (checked == true) {
                                              selectedIds.add(friend.userId);
                                            } else {
                                              selectedIds.remove(friend.userId);
                                            }
                                          });
                                        },
                                      ),
                                      onTap: () {
                                        setSheetState(() {
                                          if (isSelected) {
                                            selectedIds.remove(friend.userId);
                                          } else {
                                            selectedIds.add(friend.userId);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// 邀请成员加入群组
  Future<void> _inviteMembers(List<String> memberIds) async {
    final ok = await _viewModel.inviteMembers(memberIds);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已邀请 ${memberIds.length} 人'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '邀请成员失败');
    }
  }
}
