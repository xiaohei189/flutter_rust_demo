import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../router/app_paths.dart';
import '../../../../ui/core/theme/app_icon_colors.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/friend_provider.dart';
import '../widgets/contact_item.dart';

/// 联系人页面
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendState = ref.watch(friendListProvider);
    final applyState = ref.watch(friendApplyProvider);
    final groupState = ref.watch(groupListProvider);
    final groupApplyState = ref.watch(groupApplicationProvider);

    return Scaffold(
      // 与「消息」列表同一套语汇：整幅白底直接铺行，不用卡片、不加分割线。
      backgroundColor: context.appColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.contactsTitle ?? '通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              context.push(AppPaths.addContact);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ContactItem(
            icon: Icons.person_add_outlined,
            iconColor: AppIconColors.blue,
            title: '新朋友',
            badgeCount: applyState.unhandledCount,
            onTap: () => context.push(AppPaths.friendRequests),
          ),
          ContactItem(
            icon: Icons.group_outlined,
            iconColor: AppIconColors.green,
            title: '我的好友',
            trailingText: '${friendState.friendCount}',
            onTap: () => context.push(AppPaths.friendList),
          ),
          ContactItem(
            icon: Icons.groups_outlined,
            iconColor: AppIconColors.purple,
            title: '我的群组',
            trailingText: '${groupState.groups.length}',
            onTap: () => context.push(AppPaths.groupList),
          ),
          ContactItem(
            icon: Icons.group_add_outlined,
            iconColor: AppIconColors.orange,
            title: '群申请',
            badgeCount: groupApplyState.unhandledCount,
            onTap: () => context.push(AppPaths.groupApplications),
          ),
        ],
      ),
    );
  }
}
