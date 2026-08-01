import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../router/app_router.dart';
import '../services/services.dart';
import '../src/rust/api/client.dart' as fb;
import '../src/rust/api/message_advanced.dart' show clearConversationAndDeleteAllMsg;
import '../src/rust/domain/model/group.dart' show GroupMember;
import '../src/rust/domain/model/local.dart' show LocalConversation;
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

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
  bool _addToMark = false;

  /// 获取会话信息
  LocalConversation? get _conversation {
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
      return User(
        id: widget.conversationId,
        name: '未知',
        avatar: null,
      );
    }
    return User(
      id: conversation.userId.isNotEmpty
          ? conversation.userId
          : conversation.groupId,
      name: _displayName,
      avatar: conversation.faceUrl.isNotEmpty
          ? conversation.faceUrl
          : null,
    );
  }

  /// 获取客户端实例
  fb.OpenImBridgeClient? get _client =>
      ref.read(messageServiceProvider.notifier).client;

  @override
  void initState() {
    super.initState();
    final conversation = _conversation;
    if (conversation != null) {
      _muteNotification = conversation.recvMsgOpt == 1;
      _pinChat = conversation.isPinned == 1;
    } else {
      _muteNotification = false;
      _pinChat = false;
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
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('设置'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => AppRouter.goBack(context),
          ),
        ),
        body: const Center(
          child: Text('会话不存在'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ---- 顶部：成员区域 ----
          _buildCard(
            children: [
              if (_isGroup) ..._buildGroupHeader() else ..._buildSingleHeader(),
            ],
          ),

          // ---- 群成员（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            _buildCard(children: _buildGroupMembers()),
          ],

          // ---- 应用 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildSectionTitle(_isGroup ? '群应用' : '应用'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  if (_isGroup)
                    _buildAppIcon(Icons.campaign_outlined, '群公告', AppTheme.primaryColor),
                  _buildAppIcon(Icons.edit_outlined, '任务', AppTheme.primaryColor),
                  _buildAppIcon(Icons.push_pin_outlined, 'Pin', const Color(0xFF34C759)),
                  _buildAppIcon(
                    Icons.calendar_month_outlined,
                    _isGroup ? '群成员日历' : '查看日历',
                    const Color(0xFFFF9500),
                  ),
                ],
              ),
            ),
          ]),

          // ---- 搜索会话内容 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('搜索会话内容', onTap: () {}),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  _buildSearchIcon(Icons.chat_bubble_outline, '消息'),
                  _buildSearchIcon(Icons.description_outlined, '云文档'),
                  _buildSearchIcon(Icons.folder_outlined, '文件'),
                  _buildSearchIcon(Icons.image_outlined, '图片/视频'),
                  _buildSearchIcon(Icons.link, '链接'),
                ],
              ),
            ),
          ]),

          // ---- 添加标签页 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('添加标签页', onTap: () {}),
          ]),

          // ---- 群机器人 + 群昵称（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            _buildCard(children: [
              _buildNavRow('群机器人', onTap: () {}),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildNavRow('群昵称', onTap: () {}),
            ]),
          ],

          // ---- 开关设置区 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildSwitchRow('消息免打扰', _muteNotification, (v) async {
              setState(() => _muteNotification = v);
              final client = _client;
              if (client != null) {
                try {
                  await client.setConversation(
                    conversationId: widget.conversationId,
                    recvMsgOpt: v ? 1 : 0,
                  );
                } catch (_) {}
              }
            }),
            if (_isGroup) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSwitchRow('@所有人的消息不提示', false, (_) {}),
            ],
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildSwitchRow('置顶会话', _pinChat, (v) async {
              setState(() => _pinChat = v);
              final client = _client;
              if (client != null) {
                try {
                  await client.setConversationPinned(
                    conversationId: widget.conversationId,
                    isPinned: v,
                  );
                } catch (_) {}
              }
            }),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildNavRow('标签', onTap: () {}),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildSwitchRow('添加到标记', _addToMark, (v) {
              setState(() => _addToMark = v);
            }),
          ]),

          // ---- 翻译助手 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('翻译助手', onTap: () {}),
          ]),

          // ---- 清空聊天记录 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('清空聊天记录', onTap: _handleClearChatHistory),
          ]),

          // ---- 退出群组（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            _buildCard(children: [
              InkWell(
                onTap: () => _handleQuitGroup(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      '退出群组',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.unreadRed,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
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
                  SnackBar(
                    content: const Text('已复制会话 ID'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '会话 ID: ${conversation.conversationId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_outlined,
                    size: 12,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),

          // ---- 举报 ----
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: Icon(
                Icons.warning_amber_outlined,
                size: 16,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
              ),
              label: Text(
                '举报',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondaryColor,
        ),
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
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
              onPressed: () {},
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildGroupHeader() {
    final memberCount =
        ref.watch(groupMemberProvider(widget.conversationId)).members.length;

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
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondaryColor),
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
      _buildSectionTitle(
          '群成员${memberState.isLoading ? '' : ' (${members.length})'}'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final member in members)
              _buildRealMemberAvatar(member),
            _buildAddMemberButton(),
          ],
        ),
      ),
    ];
  }

  Widget _buildRealMemberAvatar(GroupMember member) {
    final displayName = member.nickname.isNotEmpty ? member.nickname : member.userId;
    final user = User(
      id: member.userId,
      name: displayName,
      avatar: member.faceUrl.isNotEmpty ? member.faceUrl : null,
    );

    return Column(
      children: [
        UserAvatar(user: user, radius: 20),
        const SizedBox(height: 4),
        SizedBox(
          width: 48,
          child: Text(
            displayName,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryColor),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildAddMemberButton() {
    return GestureDetector(
      onTap: () => _showInviteMemberDialog(),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.dividerColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.add, color: AppTheme.textSecondaryColor, size: 20),
          ),
          const SizedBox(height: 4),
          const Text(
            '添加',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(IconData icon, String label, Color color) {
    return Expanded(
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
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchIcon(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textSecondaryColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimaryColor),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimaryColor),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// 退出群组
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
            child: const Text('退出', style: TextStyle(color: AppTheme.unreadRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final client = _client;
    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('客户端未初始化')),
        );
      }
      return;
    }

    try {
      await GroupService.instance.quitGroup(
        client,
        groupId: widget.conversationId,
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出群组失败: $e')),
        );
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
            child: const Text('清空', style: TextStyle(color: AppTheme.unreadRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final client = _client;
    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('客户端未初始化')),
        );
      }
      return;
    }

    try {
      await clearConversationAndDeleteAllMsg(
        conversationId: widget.conversationId,
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空聊天记录失败: $e')),
        );
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
                              horizontal: 16, vertical: 12),
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
                                        ? AppTheme.textSecondaryColor
                                        : AppTheme.primaryColor,
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
                                  ? const Center(
                                      child: Text(
                                        '暂无好友',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: scrollController,
                                      itemCount: friendState.friends.length,
                                      itemBuilder: (context, index) {
                                        final friend =
                                            friendState.friends[index];
                                        final isSelected = selectedIds
                                            .contains(friend.userId);

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
                                            style:
                                                const TextStyle(fontSize: 15),
                                          ),
                                          trailing: Checkbox(
                                            value: isSelected,
                                            activeColor: AppTheme.primaryColor,
                                            onChanged: (checked) {
                                              setSheetState(() {
                                                if (checked == true) {
                                                  selectedIds
                                                      .add(friend.userId);
                                                } else {
                                                  selectedIds
                                                      .remove(friend.userId);
                                                }
                                              });
                                            },
                                          ),
                                          onTap: () {
                                            setSheetState(() {
                                              if (isSelected) {
                                                selectedIds
                                                    .remove(friend.userId);
                                              } else {
                                                selectedIds
                                                    .add(friend.userId);
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
    final client = _client;
    if (client == null) return;

    try {
      await GroupService.instance.inviteGroupMembers(
        client,
        groupId: widget.conversationId,
        memberIds: memberIds,
      );
      // 邀请成功后重新加载成员列表
      await ref
          .read(groupMemberProvider(widget.conversationId).notifier)
          .loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已邀请 ${memberIds.length} 人'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('邀请成员失败: $e')),
        );
      }
    }
  }
}
