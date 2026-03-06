import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 网络状态小标签
class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({
    required this.isFailed,
    required this.label,
  });

  final bool isFailed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        color: isFailed
            ? const Color(0xFFFFE1DD)
            : const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFailed)
            const Icon(Icons.sync_problem, size: 12, color: Color(0xFFFF381F))
          else
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isFailed
                  ? const Color(0xFFFF381F)
                  : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 会话列表顶部栏
/// 左侧：用户头像（点击进入侧边栏/设置）
/// 中间：「消息」标题 + 网络状态指示（如「连接中...」）
/// 右侧：「+」图标（发起群聊、扫一扫、添加好友）
class ConversationTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const ConversationTitleBar({
    super.key,
    required this.currentUserId,
    this.nickname,
    this.avatarUrl,
    required this.isSyncing,
    required this.isConnected,
    this.syncProgress = 0,
    this.onAvatarTap,
    this.onAddFriend,
    this.onAddGroup,
    this.onCreateGroup,
    this.onScan,
    this.onRefresh,
  });

  final String currentUserId;
  final String? nickname;
  final String? avatarUrl;
  final bool isSyncing;
  final bool isConnected;
  final int syncProgress;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAddFriend;
  final VoidCallback? onAddGroup;
  final VoidCallback? onCreateGroup;
  final VoidCallback? onScan;
  final VoidCallback? onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final showStatus = isSyncing || !isConnected;
    final statusStr = isSyncing
        ? (syncProgress > 0 ? '同步中 $syncProgress%' : '连接中...')
        : '连接失败';

    return AppBar(
      toolbarHeight: 56,
      titleSpacing: 0,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '消息',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showStatus)
            _SyncStatusChip(
              isFailed: !isConnected,
              label: statusStr,
            ),
        ],
      ),
      leading: IconButton(
        icon: CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
          backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
              ? NetworkImage(avatarUrl!)
              : null,
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? Text(
                  nickname?.isNotEmpty == true
                      ? nickname!.substring(0, 1).toUpperCase()
                      : currentUserId.isNotEmpty
                          ? currentUserId.substring(0, 1).toUpperCase()
                          : '我',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        onPressed: onAvatarTap ?? () {
          // 默认可进入设置/侧边栏，由外部传入 onAvatarTap
        },
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.add_circle_outline, size: 26),
          padding: const EdgeInsets.only(right: 8),
          onSelected: (value) {
            switch (value) {
              case 'add_friend':
                onAddFriend?.call();
                break;
              case 'add_group':
                onAddGroup?.call();
                break;
              case 'create_group':
                onCreateGroup?.call();
                break;
              case 'scan':
                onScan?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'add_friend',
              child: ListTile(
                leading: Icon(Icons.person_add_outlined),
                title: Text('添加好友'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'add_group',
              child: ListTile(
                leading: Icon(Icons.group_add_outlined),
                title: Text('加群'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'create_group',
              child: ListTile(
                leading: Icon(Icons.group_outlined),
                title: Text('发起群聊'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'scan',
              child: ListTile(
                leading: Icon(Icons.qr_code_scanner_outlined),
                title: Text('扫一扫'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
