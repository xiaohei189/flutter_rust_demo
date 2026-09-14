import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../ui/core/widgets/list_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/views/group_members_screen.dart';
import '../providers/chat_settings_provider.dart';
import '../view_models/chat_settings_view_model.dart';
import '../widgets/settings_components.dart';
import '../widgets/settings_dialogs.dart';
import '../widgets/chat_message_search_sheet.dart';

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
        centerTitle: true,
        title: Text(l10n?.chatSettingsTitle ?? '设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20),
            tooltip: '分享',
            onPressed: () => _notSupported('分享'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ---- 顶部：成员区域 ----
          SettingsCard(
            children: [
              if (isGroup) ...[
                // 群信息 + 群成员同卡（对齐飞书稿）
                ..._buildGroupHeader(),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ..._buildGroupMembers(),
              ] else
                ..._buildSingleHeader(),
            ],
          ),

          // ---- 应用（对齐飞书稿：任务 / Pin；群聊另有群公告、群成员日历）----
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              const SettingsSectionTitle(title: '应用'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    if (isGroup)
                      _buildAppIcon(
                        Icons.campaign_outlined,
                        l10n?.groupAnnouncement ?? '群公告',
                        context.appColors.primary,
                        onTap: _editGroupAnnouncement,
                      ),
                    _buildAppIcon(
                      Icons.task_alt,
                      '任务',
                      const Color(0xFF7F3BF5),
                      onTap: () => _notSupported('任务'),
                    ),
                    _buildAppIcon(
                      Icons.push_pin_outlined,
                      'Pin',
                      const Color(0xFF00B42A),
                      onTap: () => _notSupported('Pin'),
                    ),
                    if (isGroup)
                      _buildAppIcon(
                        Icons.calendar_month_outlined,
                        '群成员日历',
                        const Color(0xFFFF8A00),
                        onTap: () => _notSupported('群成员日历'),
                      )
                    else ...[
                      const Spacer(),
                      const Spacer(),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ---- 搜索会话内容（对齐飞书稿） ----
          SettingsCard(
            children: [
              ListRow(
                label: '搜索会话内容',
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.appColors.textSecondary,
                ),
                onTap: _showMessageSearch,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    _buildAppIcon(
                      Icons.chat_bubble_outline,
                      '消息',
                      context.appColors.textPrimary,
                      onTap: _showMessageSearch,
                    ),
                    _buildAppIcon(
                      Icons.description_outlined,
                      '云文档',
                      context.appColors.textPrimary,
                      onTap: () => _notSupported('云文档'),
                    ),
                    _buildAppIcon(
                      Icons.folder_outlined,
                      '文件',
                      context.appColors.textPrimary,
                      onTap: () => _notSupported('文件'),
                    ),
                    _buildAppIcon(
                      Icons.image_outlined,
                      '图片/视频',
                      context.appColors.textPrimary,
                      onTap: () => _notSupported('图片/视频'),
                    ),
                    _buildAppIcon(
                      Icons.link,
                      '链接',
                      context.appColors.textPrimary,
                      onTap: () => _notSupported('链接'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: '添加标签页',
                onTap: () => _notSupported('添加标签页'),
              ),
            ],
          ),

          // ---- 群机器人（仅群聊，占位） ----
          if (isGroup) ...[
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                SettingsNavRow(
                  title: '群机器人',
                  onTap: () => _notSupported('群机器人'),
                ),
              ],
            ),
          ],

          // ---- 开关组（对齐飞书稿：免打扰 / 置顶会话 / 标签 / 添加到标记） ----
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              if (isGroup) ...[
                SettingsNavRow(
                  title: l10n?.groupNickname ?? '群昵称',
                  onTap: _editGroupNickname,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              SettingsSwitchRow(
                title: l10n?.muteNotification ?? '消息免打扰',
                value: settings.muteNotification,
                onChanged: _setMuteNotification,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              if (isGroup) ...[
                SettingsSwitchRow(
                  title: '@所有人的消息不提示',
                  value: false,
                  onChanged: (_) => _notSupported('@所有人的消息不提示'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              SettingsSwitchRow(
                title: l10n?.pinChat ?? '置顶会话',
                value: settings.pinChat,
                onChanged: _setPinChat,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsNavRow(title: '标签', onTap: () => _notSupported('标签')),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsSwitchRow(
                title: '添加到标记',
                value: false,
                onChanged: (_) => _notSupported('添加到标记'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsSwitchRow(
                title: l10n?.privateChat ?? '私聊（阅后即焚）',
                value: settings.privateChat,
                onChanged: _setPrivateChat,
              ),
            ],
          ),

          // ---- 翻译助手（对齐飞书稿，占位） ----
          const SizedBox(height: 8),
          SettingsCard(
            children: [
              SettingsNavRow(title: '翻译助手', onTap: () => _notSupported('翻译助手')),
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
          // ---- 举报（对齐飞书稿，占位） ----
          if (isGroup)
            Center(
              child: TextButton.icon(
                onPressed: () => _notSupported('举报'),
                icon: Icon(
                  Icons.error_outline,
                  size: 16,
                  color: context.appColors.textSecondary,
                ),
                label: Text(
                  '举报',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
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

  /// 单聊顶部：头像 + 名字（名字在头像下方）+「+」添加成员（对齐飞书稿）
  List<Widget> _buildSingleHeader() {
    final conversation = _viewModel.conversation;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMemberTile(
              name: _viewModel.displayName,
              avatar: UserAvatar(user: _viewModel.chatUser, radius: 26),
              onTap: () {
                if (conversation != null && conversation.userId.isNotEmpty) {
                  AppRouter.goToUserProfile(
                    context,
                    userId: conversation.userId,
                  );
                }
              },
            ),
            const SizedBox(width: 24),
            _buildAddMemberTile(onTap: () => _notSupported('添加成员')),
          ],
        ),
      ),
    ];
  }

  /// 设置页顶部的成员块：头像 + 名字（名字居中在头像下方）
  Widget _buildMemberTile({
    required String name,
    required Widget avatar,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 设置页顶部的「+」块：添加成员 / 邀请
  Widget _buildAddMemberTile({required VoidCallback onTap}) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.divider),
        ),
        child: Icon(Icons.add, size: 26, color: colors.textSecondary),
      ),
    );
  }

  List<Widget> _buildGroupHeader() {
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // 对齐飞书稿：无群描述时展示占位文案「群描述」
                      '群描述',
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
                  Icons.qr_code_2,
                  size: 20,
                  color: context.appColors.textSecondary,
                ),
                tooltip: '群二维码',
                onPressed: () => _notSupported('群二维码'),
              ),
              IconButton(
                padding: EdgeInsets.zero,
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
      // 群成员标题行可点：进入独立的群成员页（对齐飞书）
      InkWell(
        onTap: _openMembersPage,
        child: Row(
          children: [
            Expanded(
              child: SettingsSectionTitle(
                title:
                    '群成员${memberState.isLoading ? '' : ' (${members.length})'}',
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.appColors.textSecondary,
            ),
            const SizedBox(width: 16),
          ],
        ),
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

  void _openMembersPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupMembersScreen(groupId: _viewModel.groupId),
      ),
    );
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

  /// 尚未实现的功能：按稿子摆位，点击提示「暂未开放」。
  void _notSupported(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$label」暂未开放'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  /// 打开会话内消息搜索（搜索会话内容 → 消息）
  void _showMessageSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChatMessageSearchSheet(
        conversationId: widget.conversationId,
        onMessageTap: (_) => Navigator.of(context).pop(),
      ),
    );
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
