import 'package:flutter/material.dart';

import '../../../../domain/models/user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';

/// 聊天详情页顶栏：返回、会话信息、在线状态、搜索与设置入口。
class ChatDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatDetailAppBar({
    super.key,
    required this.user,
    required this.unread,
    required this.isTyping,
    required this.isGroup,
    required this.onBack,
    required this.onOpenSettings,
    required this.onSearch,
    this.online,
  });

  final User user;
  final int unread;
  final bool isTyping;
  final bool isGroup;
  final bool? online;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      leading: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.arrow_back_ios_new, size: 22),
            if (unread > 0)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.appColors.danger,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: TextStyle(
                      color: context.appColors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onPressed: onBack,
      ),
      title: InkWell(
        onTap: onOpenSettings,
        child: Row(
          children: [
            UserAvatar(user: user, radius: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  if (isTyping)
                    Text(
                      '对方正在输入...',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appColors.primary.withValues(alpha: 0.9),
                      ),
                    )
                  else if (isGroup)
                    Text(
                      '群聊',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    )
                  else
                    Text(
                      switch (online) {
                        true => '在线',
                        false => '离线',
                        null => '未知',
                      },
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Semantics(
          label: '搜索聊天记录',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索聊天记录',
            onPressed: onSearch,
          ),
        ),
        Semantics(
          label: '更多设置',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: '更多设置',
            onPressed: onOpenSettings,
          ),
        ),
      ],
    );
  }
}