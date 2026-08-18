import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 会话列表顶部栏（参考飞书风格）
/// 左侧：用户头像 + 昵称/用户名
/// 右侧：搜索图标 + 「+」按钮
class ConversationTitleBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ConversationTitleBar({
    super.key,
    required this.currentUserId,
    this.nickname,
    this.avatarUrl,
    required this.isSyncing,
    required this.isConnected,
    this.syncProgress = 0,
    this.onAvatarTap,
    this.onSearchTap,
    this.onAddFriend,
    this.onAddGroup,
    this.onCreateGroup,
    this.onScan,
    this.onHideAll,
    this.onRefresh,
  });

  final String currentUserId;
  final String? nickname;
  final String? avatarUrl;
  final bool isSyncing;
  final bool isConnected;
  final int syncProgress;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAddFriend;
  final VoidCallback? onAddGroup;
  final VoidCallback? onCreateGroup;
  final VoidCallback? onScan;
  final VoidCallback? onHideAll;
  final VoidCallback? onRefresh;

  String get _displayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    if (currentUserId.isNotEmpty) return currentUserId;
    return '我';
  }

  String get _avatarInitial {
    if (nickname != null && nickname!.isNotEmpty) {
      final cn = RegExp(r'[\u4e00-\u9fa5]').firstMatch(nickname!);
      if (cn != null) return cn.group(0)!;
      return nickname!.substring(0, 1).toUpperCase();
    }
    if (currentUserId.isNotEmpty) {
      return currentUserId.substring(0, 1).toUpperCase();
    }
    return '我';
  }

  /// 判断是否为本地文件路径
  bool _isLocalPath(String path) {
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('ftp://')) {
      return false;
    }
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(path)) {
      return true;
    }
    if (path.startsWith('/')) {
      return true;
    }
    return false;
  }

  ImageProvider? _getAvatarImage() {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (_isLocalPath(avatarUrl!)) {
      return FileImage(File(avatarUrl!));
    }
    return NetworkImage(avatarUrl!);
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppBar(
      toolbarHeight: 56,
      titleSpacing: 0,
      backgroundColor: colors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 左侧：头像 + 名字
            GestureDetector(
              onTap: onAvatarTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primary.withValues(alpha: 0.15),
                    backgroundImage: _getAvatarImage(),
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? Text(
                            _avatarInitial,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isConnected)
                        Text(
                          '连接失败',
                          style: TextStyle(fontSize: 11, color: colors.danger),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 右侧：搜索 + 加号
            Semantics(
              label: '搜索',
              button: true,
              child: IconButton(
                key: const ValueKey('chat_search_button'),
                icon: const Icon(Icons.search, size: 26),
                color: colors.textPrimary,
                onPressed: onSearchTap,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_circle_outline, size: 26),
              color: colors.surface,
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
                  case 'hide_all':
                    onHideAll?.call();
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
                const PopupMenuItem(
                  value: 'hide_all',
                  child: ListTile(
                    leading: Icon(Icons.visibility_off_outlined),
                    title: Text('隐藏全部会话'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
