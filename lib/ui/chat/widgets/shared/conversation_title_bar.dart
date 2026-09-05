import 'package:flutter/material.dart';

import '../../../../domain/models/user.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/theme/app_theme.dart';

/// 会话列表顶部栏（参考飞书风格）
/// 左侧：用户头像 + 昵称/用户名
/// 右侧：搜索图标 + 「+」按钮（仅保留列表批量操作「多选管理」，
/// 其余应用类入口已收敛到「工作台」Tab）
class ConversationTitleBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ConversationTitleBar({
    super.key,
    required this.currentUserId,
    this.nickname,
    this.avatarUrl,
    this.statusText,
    required this.isSyncing,
    required this.isConnected,
    this.syncProgress = 0,
    this.onAvatarTap,
    this.onSearchTap,
    this.onManage,
    this.onRefresh,
  });

  final String currentUserId;
  final String? nickname;
  final String? avatarUrl;
  final String? statusText;
  final bool isSyncing;
  final bool isConnected;
  final int syncProgress;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onManage;
  final VoidCallback? onRefresh;

  String get _displayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    if (currentUserId.isNotEmpty) return currentUserId;
    return '我';
  }

  /// 头像下方的状态/签名行（连接失败时优先显示错误）。
  String get _statusText => statusText?.trim() ?? '';

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
            // 左侧：头像 + 名字（大头像 + 状态点 + 大昵称）
            GestureDetector(
              key: const ValueKey('chat_avatar_button'),
              onTap: onAvatarTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 复用列表同款 UserAvatar：实色底 + 全名，图片/回退一致，底色统一。
                      UserAvatar(
                        user: User(
                          id: currentUserId,
                          name: _displayName,
                          avatar: avatarUrl,
                        ),
                        radius: kConversationAvatarRadius,
                      ),
                      // 在线/忙碌状态点
                      if (isConnected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      if (!isConnected)
                        Text(
                          '连接失败',
                          style: TextStyle(fontSize: 11, color: colors.danger),
                        )
                      else
                        // 对齐设计稿：昵称下方常显一行状态；未设签名时用默认「在线」。
                        Text(
                          _statusText.isNotEmpty ? _statusText : '在线',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 右侧：搜索 + 加号（列表批量操作入口）
            Semantics(
              label: '搜索',
              button: true,
              child: IconButton(
                key: const ValueKey('chat_search_button'),
                icon: const Icon(Icons.search, size: 30),
                color: colors.textPrimary,
                onPressed: onSearchTap,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.add_circle, size: 30, color: colors.textPrimary),
              color: colors.surface,
              onSelected: (value) {
                switch (value) {
                  case 'manage':
                    onManage?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'manage',
                  child: ListTile(
                    leading: Icon(Icons.checklist),
                    title: Text('多选管理'),
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
