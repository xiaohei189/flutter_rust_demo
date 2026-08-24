import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../view_models/chat_settings_view_model.dart';
import '../widgets/settings_components.dart';
import '../widgets/settings_dialogs.dart';

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
      // Riverpod 禁止在 initState 中修改 provider 状态（initialize 内部会 state=...），
      // 延迟到首帧之后执行，避免 "Tried to modify a provider while the widget tree was building"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewModel.initialize(conversation);
      });
    }
    if (_viewModel.isGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_viewModel.loadGroupMembers());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(
      chatSettingsViewModelProvider(widget.conversationId),
    );
    final conversation = _viewModel.conversation;
    final isGroup = _viewModel.isGroup;

    if (conversation == null) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          title: Text(l10n?.chatSettingsTitle ?? '设置'),
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
        title: Text(l10n?.chatSettingsTitle ?? '设置'),
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
                SettingsSectionTitle(title: l10n?.groupApps ?? '群应用'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      _buildAppIcon(
                        Icons.campaign_outlined,
                        l10n?.groupAnnouncement ?? '群公告',
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
                SettingsNavRow(
                  title: l10n?.groupNickname ?? '群昵称',
                  onTap: _editGroupNickname,
                ),
              ],
            ),
          ],

          // ---- 开关设置区 ----
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsSwitchRow(
                title: l10n?.muteNotification ?? '消息免打扰',
                value: settings.muteNotification,
                onChanged: _setMuteNotification,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsSwitchRow(
                title: l10n?.pinChat ?? '置顶会话',
                value: settings.pinChat,
                onChanged: _setPinChat,
              ),
              if (!isGroup) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SettingsSwitchRow(
                  title: l10n?.privateChat ?? '私聊（阅后即焚）',
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
              SettingsNavRow(
                title: l10n?.clearHistory ?? '清空聊天记录',
                onTap: _handleClearChatHistory,
              ),
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
                        l10n?.quitGroup ?? '退出群组',
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
    final conversation = _viewModel.conversation;
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (conversation != null && conversation.userId.isNotEmpty) {
              AppRouter.goToUserProfile(context, userId: conversation.userId);
            }
          },
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
                onPressed: () {
                  if (conversation != null &&
                      conversation.userId.isNotEmpty) {
                    AppRouter.goToUserProfile(
                      context,
                      userId: conversation.userId,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildGroupHeader() {
    final memberCount = ref
        .watch(groupMemberProvider(_viewModel.groupId))
        .members
        .length;
    final conversation = _viewModel.conversation;

    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (conversation != null) {
              AppRouter.goToGroupInfo(context, conversation);
            }
          },
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
                onPressed: () {
                  if (conversation != null) {
                    AppRouter.goToGroupInfo(context, conversation);
                  }
                },
              ),
            ],
          ),
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
    final confirmed = await confirmQuitGroup(context);

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
    final confirmed = await confirmClearChatHistory(context);

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
    final nickname = await showChatSettingsTextDialog(
      context,
      title: '修改群昵称',
      hint: '请输入群昵称',
    );
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

    final value = await showChatSettingsTextDialog(
      context,
      title: '编辑群公告',
      hint: '请输入群公告',
      initialValue: current,
      maxLines: 6,
    );
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
    showInviteMemberSheet(context, onInvite: (ids) => _inviteMembers(ids));
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
