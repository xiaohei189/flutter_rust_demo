import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../widgets/settings_components.dart';

/// 聊天设置页面：单聊 / 群聊 分别展示不同内容
class ChatSettingsScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatSettingsScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  late bool _muteNotification;
  late bool _pinChat;
  late bool _privateChat;

  /// 获取会话信息
  Conversation? get _conversation {
    // 先尝试从新的 ConversationService 获取
    final newService = ref.read(conversationServiceProvider);
    var conversation = newService.getConversation(widget.conversationId);
    if (conversation != null) return conversation;

    // 如果新服务没有，尝试从旧的 conversationListProvider 获取
    final oldState = ref.read(conversationListProvider);
    conversation = oldState.conversations
        .where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
    return conversation;
  }

  bool get _isGroup {
    final conversation = _conversation;
    if (conversation == null) return false;
    return conversation.conversationType == 2 ||
        conversation.conversationType == 3;
  }

  String get _groupId {
    final conversation = _conversation;
    if (conversation == null) return widget.conversationId;
    return conversation.groupId.isNotEmpty
        ? conversation.groupId
        : widget.conversationId;
  }

  String get _displayName {
    final conversation = _conversation;
    if (conversation == null) return '未知';
    return conversation.showName.isNotEmpty
        ? conversation.showName
        : _isGroup
        ? '群聊'
        : '用户';
  }

  User get _chatUser {
    final conversation = _conversation;
    if (conversation == null) {
      return User(id: widget.conversationId, name: '未知', avatar: null);
    }
    return User(
      id: conversation.userId.isNotEmpty
          ? conversation.userId
          : conversation.groupId,
      name: _displayName,
      avatar: conversation.faceUrl.isNotEmpty ? conversation.faceUrl : null,
    );
  }

  @override
  void initState() {
    super.initState();
    final conversation = _conversation;
    if (conversation != null) {
      _muteNotification = conversation.recvMsgOpt == 1;
      _pinChat = conversation.isPinned;
      _privateChat = conversation.isPrivateChat;
    } else {
      _muteNotification = false;
      _pinChat = false;
      _privateChat = false;
    }
    // 群聊时加载真实群成员
    if (_isGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(groupMemberProvider(widget.conversationId).notifier)
            .loadMembers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

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
              if (_isGroup) ..._buildGroupHeader() else ..._buildSingleHeader(),
            ],
          ),

          // ---- 群成员（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            SettingsCard(children: _buildGroupMembers()),
          ],

          // ---- 应用 ----
          if (_isGroup) ...[
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
                value: _muteNotification,
                onChanged: (v) async {
                  setState(() => _muteNotification = v);
                  try {
                    await ref
                        .read(messageRepositoryProvider)
                        .setConversation(
                          conversationId: widget.conversationId,
                          recvMsgOpt: v ? 1 : 0,
                        );
                  } catch (_) {}
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SettingsSwitchRow(
                title: '置顶会话',
                value: _pinChat,
                onChanged: (v) async {
                  setState(() => _pinChat = v);
                  try {
                    await ref
                        .read(messageRepositoryProvider)
                        .setConversationPinned(
                          conversationId: widget.conversationId,
                          isPinned: v,
                        );
                  } catch (_) {}
                },
              ),
              if (!_isGroup) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SettingsSwitchRow(
                  title: '私聊（阅后即焚）',
                  value: _privateChat,
                  onChanged: (v) async {
                    setState(() => _privateChat = v);
                    try {
                      await ref
                          .read(messageRepositoryProvider)
                          .setConversationPrivate(
                            conversationId: widget.conversationId,
                            isPrivate: v,
                          );
                    } catch (_) {}
                  },
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
          if (_isGroup) ...[
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
            UserAvatar(user: _chatUser, radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
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
        .watch(groupMemberProvider(widget.conversationId))
        .members
        .length;

    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(user: _chatUser, radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
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
    final memberState = ref.watch(groupMemberProvider(widget.conversationId));
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

    try {
      await ref.read(groupRepositoryProvider).quitGroup(widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已退出群组'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('退出群组失败: $e')));
      }
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

    try {
      await ref
          .read(messageRepositoryProvider)
          .clearConversationAndDeleteAllMsg(widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('聊天记录已清空'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清空聊天记录失败: $e')));
      }
    }
  }

  /// 修改自己在群里的昵称
  Future<void> _editGroupNickname() async {
    final currentUserId = ref.read(userProfileProvider).profile?.userId ?? '';
    if (currentUserId.isEmpty) return;
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
    if (nickname == null || nickname.isEmpty) return;
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupMemberInfo(
            widget.conversationId,
            currentUserId,
            nickname: nickname,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群昵称已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  /// 编辑群公告
  Future<void> _editGroupAnnouncement() async {
    var current = '';
    try {
      final groups = await ref.read(groupRepositoryProvider).getGroupsInfo([
        _groupId,
      ]);
      current = groups.isNotEmpty ? groups.first.notification : '';
    } catch (_) {
      // 拉取失败时允许直接编辑
    }
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

    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(_groupId, notification: value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群公告已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('群公告更新失败: $e')));
      }
    }
  }

  /// 显示邀请成员对话框
  void _showInviteMemberDialog() {
    final selectedIds = <String>[];

    // 先加载好友列表
    ref.read(friendListProvider.notifier).loadFriends();

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
    final ok = await ref
        .read(groupMemberProvider(widget.conversationId).notifier)
        .inviteMembers(memberIds);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已邀请 ${memberIds.length} 人'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('邀请成员失败')));
    }
  }
}
