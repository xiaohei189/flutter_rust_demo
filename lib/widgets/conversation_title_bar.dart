import 'package:flutter/material.dart';

/// 会话列表标题栏左侧的同步/连接状态（与 openim SyncStatusView 对齐）
class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({
    required this.isFailed,
    required this.label,
  });

  final bool isFailed;
  final String label;

  static const _colorFailedBg = Color(0xFFFFE1DD);
  static const _colorFailedText = Color(0xFFFF381F);
  static const _colorSyncingBg = Color(0xFFF2F8FF);
  static const _colorSyncingText = Color(0xFF0089FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: isFailed ? _colorFailedBg : _colorSyncingBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFailed)
            Icon(Icons.sync_problem, size: 14, color: _colorFailedText)
          else
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _colorSyncingText,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isFailed ? _colorFailedText : _colorSyncingText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 会话列表标题栏（与 openim-flutter-demo TitleBar.conversation 对齐）
/// 左侧：当前用户头像 + 昵称 + 同步/连接状态；右侧：加号菜单（添加好友、加群、建群）
class ConversationTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const ConversationTitleBar({
    super.key,
    required this.currentUserId,
    this.nickname,
    this.avatarUrl,
    required this.isSyncing,
    required this.isConnected,
    this.syncProgress = 0,
    this.onRefresh,
    this.onAddFriend,
    this.onAddGroup,
    this.onCreateGroup,
  });

  final String currentUserId;
  final String? nickname;
  final String? avatarUrl;
  final bool isSyncing;
  final bool isConnected;
  final int syncProgress;
  final VoidCallback? onRefresh;
  final VoidCallback? onAddFriend;
  final VoidCallback? onAddGroup;
  final VoidCallback? onCreateGroup;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final showStatus = isSyncing || !isConnected;
    final statusFailed = !isConnected;
    final statusStr = isSyncing
        ? (syncProgress > 0 ? '同步中($syncProgress%)' : '同步中')
        : '连接失败';

    return AppBar(
      toolbarHeight: 56,
      titleSpacing: 0,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: Colors.blue.shade100,
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
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nickname?.isNotEmpty == true ? nickname! : '我',
                style: const TextStyle(
                  color: Color(0xFF0C1C33),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showStatus) ...[
              const SizedBox(width: 12),
              _SyncStatusChip(
                isFailed: statusFailed,
                label: statusStr,
              ),
            ],
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.add_circle_outline, size: 28),
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
                title: Text('建群'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
