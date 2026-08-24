import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../providers/im_providers.dart';
import '../../../../domain/models/group_member.dart';
import '../../../../domain/models/user.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/card_layout.dart';
import '../../../../ui/core/widgets/list_row.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/group_info_provider.dart';
import '../providers/group_provider.dart';
import '../view_models/group_info_view_model.dart';
import '../widgets/group_member_section.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/group_member_actions.dart';

enum _JoinTimeFilter { all, today, week, month }

/// 群信息页面：群头像（可编辑）、群名称（可编辑）、群描述（可编辑）、群二维码（只读）
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  late final GroupInfoViewModel _viewModel;
  late final GroupMemberActions _memberActions;
  String _memberKeyword = '';
  _JoinTimeFilter _joinTimeFilter = _JoinTimeFilter.all;
  bool _avatarUploading = false;

  Conversation? get _conversation => _viewModel.conversation;
  String get _groupId => _viewModel.groupId;
  User get _groupUser => _viewModel.groupUser;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(
      groupInfoViewModelProvider(widget.conversationId).notifier,
    );
    _memberActions = GroupMemberActions(
      viewModel: _viewModel,
      roleName: _roleName,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_viewModel.load());
    });
  }

  Widget _buildOwnerManageCard(AppLocalizations? l10n) {
    return Column(
      children: [
        const SizedBox(height: 12),
        CardLayout(
          children: [
            ListRow(
              label: l10n?.muteAll ?? '全员禁言',
              trailing: Icon(
                Icons.volume_off_outlined,
                size: 20,
                color: context.appColors.textSecondary,
              ),
              onTap: () => _memberActions.showGroupManageSheet(context),
            ),
            const ListDivider(),
            ListRow(
              label: l10n?.transferOwner ?? '转让群主',
              trailing: Icon(
                Icons.swap_horiz,
                size: 20,
                color: context.appColors.textSecondary,
              ),
              onTap: () => _memberActions.transferOwner(context),
            ),
            const ListDivider(),
            DangerActionRow(
              title: l10n?.dismissGroup ?? '解散群组',
              onTap: () => _memberActions.dismissGroup(context),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final groupInfo = ref.watch(
      groupInfoViewModelProvider(widget.conversationId),
    );
    final l10n = AppLocalizations.of(context);

    if (conversation == null) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          title: const Text('群信息'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => AppRouter.goBack(context),
          ),
        ),
        body: const Center(child: Text('群组不存在')),
      );
    }

    final currentUserId = _viewModel.currentUserId;
    final memberState = ref.watch(groupMemberProvider(_groupId));
    final keyword = _memberKeyword.trim().toLowerCase();
    final now = DateTime.now();
    final joinCutoff = switch (_joinTimeFilter) {
      _JoinTimeFilter.all => null,
      _JoinTimeFilter.today => DateTime(now.year, now.month, now.day),
      _JoinTimeFilter.week => now.subtract(const Duration(days: 7)),
      _JoinTimeFilter.month => now.subtract(const Duration(days: 30)),
    };
    final visibleMembers = memberState.members.where((m) {
      final matchKeyword =
          keyword.isEmpty ||
          m.nickname.toLowerCase().contains(keyword) ||
          m.userId.toLowerCase().contains(keyword);
      final rawJoinTime = m.joinTimeMs;
      final joinTime = rawJoinTime > 946684800000
          ? rawJoinTime
          : rawJoinTime * 1000;
      final matchTime =
          joinCutoff == null || joinTime >= joinCutoff.millisecondsSinceEpoch;
      return matchKeyword && matchTime;
    }).toList();
    final currentMember = memberState.members
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final isOwner = currentMember?.roleLevel == 3;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.groupInfoTitle ?? '群信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // 群头像、群名称、群描述
          CardLayout(
            children: [
              ListRow(
                label: l10n?.groupAvatar ?? '群头像',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_avatarUploading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      UserAvatar(user: _groupUser, radius: 22),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
                onTap: _changeGroupAvatar,
              ),
              const ListDivider(),
              TwoLineListRow(
                label: l10n?.groupName ?? '群名称',
                value: groupInfo.groupName,
                onTap: () => _editField(
                  title: l10n?.editGroupName ?? '修改群名称',
                  initialValue: groupInfo.groupName,
                  onSave: _saveGroupName,
                ),
              ),
              const ListDivider(),
              TwoLineListRow(
                label: l10n?.groupDescription ?? '群描述',
                value: groupInfo.groupDescription,
                onTap: () => _editField(
                  title: l10n?.editGroupDescription ?? '修改群描述',
                  initialValue: groupInfo.groupDescription == '暂无描述'
                      ? ''
                      : groupInfo.groupDescription,
                  onSave: _saveGroupDescription,
                ),
              ),
            ],
          ),
          // 群成员
          GroupMemberSection(
            members: visibleMembers,
            keyword: _memberKeyword,
            isLoading: memberState.isLoading,
            ownerAdminCount: memberState.members
                .where((m) => m.roleLevel >= 2)
                .length,
            joinTimeFilterLabel: _joinTimeFilterLabel,
            onKeywordChanged: (value) => setState(() => _memberKeyword = value),
            onMemberTap: (member) =>
                _memberActions.showMemberActions(context, member),
            onOwnerAdminTap: () => _memberActions.showOwnerAdminList(context),
            onJoinTimeFilterTap: _showJoinTimeFilter,
          ),
          if (isOwner) _buildOwnerManageCard(l10n),
          const SizedBox(height: 12),
          // 群二维码（只读）
          CardLayout(
            children: [
              ListRow(
                label: l10n?.groupQrCode ?? '群二维码',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      size: 22,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  AppRouter.goToQrCode(
                    context,
                    title: '群二维码',
                    data: _groupId,
                    subtitle: groupInfo.groupName,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _roleName(int roleLevel) {
    return switch (roleLevel) {
      3 => '群主',
      2 => '管理员',
      _ => '成员',
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String get _joinTimeFilterLabel => switch (_joinTimeFilter) {
    _JoinTimeFilter.all => '全部',
    _JoinTimeFilter.today => '今天',
    _JoinTimeFilter.week => '近 7 天',
    _JoinTimeFilter.month => '近 30 天',
  };

  Future<void> _showJoinTimeFilter() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<_JoinTimeFilter>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n?.joinTimeFilter ?? '按加入时间筛选',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            for (final filter in _JoinTimeFilter.values)
              ListTile(
                title: Text(switch (filter) {
                  _JoinTimeFilter.all => l10n?.all ?? '全部',
                  _JoinTimeFilter.today => l10n?.today ?? '今天',
                  _JoinTimeFilter.week => l10n?.last7Days ?? '近 7 天',
                  _JoinTimeFilter.month => l10n?.last30Days ?? '近 30 天',
                }),
                trailing: _joinTimeFilter == filter
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: context.appColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(filter),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _joinTimeFilter = selected);
    }
  }

  /// 更换群头像：底部弹窗选择「从相册选择 / 输入图片链接」
  Future<void> _changeGroupAvatar() async {
    final action = await showGroupAvatarPickerSheet(context);
    if (!mounted) return;
    switch (action) {
      case 'gallery':
        await _pickAvatarFromGallery();
      case 'url':
        await _editAvatarUrl();
    }
  }

  /// 从相册选择图片，上传服务器后更新群头像
  Future<void> _pickAvatarFromGallery() async {
    final image = await ref
        .read(imagePickerServiceProvider)
        .pickImageFromGallery();
    if (image == null || !mounted) return;

    setState(() => _avatarUploading = true);
    try {
      final url = await _viewModel.uploadAvatar(image.path);
      if (url.isEmpty || url.contains('example.com')) {
        _showError('头像上传失败，请重试');
        return;
      }
      final ok = await _viewModel.updateGroupAvatar(url);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群头像已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(_viewModel.currentState.error ?? '更新失败');
      }
    } catch (e) {
      if (mounted) _showError('头像上传失败: $e');
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  /// 输入图片链接更新群头像（保留原能力）
  Future<void> _editAvatarUrl() async {
    final url = await showChangeGroupAvatarDialog(
      context,
      initialUrl: _conversation?.faceUrl ?? '',
    );
    if (url == null || url.isEmpty || !mounted) return;
    final ok = await _viewModel.updateGroupAvatar(url);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群头像已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '更新失败');
    }
  }

  void _editField({
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
  }) {
    showEditGroupFieldDialog(
      context,
      title: title,
      initialValue: initialValue,
      onSave: onSave,
      maxLines: maxLines,
    );
  }

  Future<void> _saveGroupName(String value) async {
    final ok = await _viewModel.updateGroupName(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群名称已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '群名称更新失败');
    }
  }

  Future<void> _saveGroupDescription(String value) async {
    final ok = await _viewModel.updateGroupDescription(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群描述已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '群描述更新失败');
    }
  }
}
