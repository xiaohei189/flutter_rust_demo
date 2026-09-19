import 'package:flutter/material.dart';

import '../../../domain/models/friend.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/user.dart';
import '../../previews/app_theme_preview.dart';
import '../../previews/fake_data.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import 'contact_pick_item.dart';

/// 联系人选择器列表：好友 + 群组分区展示。
class ContactPickerList extends StatelessWidget {
  const ContactPickerList({
    super.key,
    required this.friends,
    required this.groups,
    required this.keyword,
    required this.multiSelect,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Friend> friends;
  final List<Group> groups;
  final String keyword;
  final bool multiSelect;
  final Set<String> selectedIds;
  final ValueChanged<ContactPickItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final hasFriends = friends.isNotEmpty;
    final hasGroups = groups.isNotEmpty;

    if (!hasFriends && !hasGroups) {
      return Center(
        child: Text(
          keyword.isEmpty ? '暂无联系人' : '未找到匹配结果',
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    // 好友/群组数量可能上千，且输入关键字时会随每次筛选重建：
    // 用 ListView.builder + 摊平条目，保证每帧只构建可视区域内的行。
    final items = <_ContactPickerRow>[
      if (hasFriends) ...[
        _ContactPickerSection('我的好友', friends.length),
        for (final friend in friends) _ContactPickerFriend(friend),
      ],
      if (hasGroups) ...[
        _ContactPickerSection('我的群组', groups.length),
        for (final group in groups) _ContactPickerGroup(group),
      ],
    ];

    return ListView.builder(
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) return const SizedBox(height: 80);
        return switch (items[index]) {
          _ContactPickerSection(:final title, :final count) =>
            _buildSectionHeader(context, title, count),
          _ContactPickerFriend(:final friend) => _buildFriendItem(
            context,
            friend,
          ),
          _ContactPickerGroup(:final group) => _buildGroupItem(context, group),
        };
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(BuildContext context, Friend friend) {
    final id = friend.userId;
    final displayName = friend.remark.isNotEmpty
        ? friend.remark
        : friend.nickname;
    final isSelected = selectedIds.contains(id);

    return InkWell(
      onTap: () => onToggle(
        ContactPickItem(
          id: id,
          name: displayName,
          avatarUrl: friend.faceUrl,
          isGroup: false,
        ),
      ),
      child: Container(
        color: context.appColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar.fromUser(
              user: User(
                id: id,
                name: displayName,
                avatar: friend.faceUrl.isNotEmpty ? friend.faceUrl : null,
              ),
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  if (friend.remark.isNotEmpty)
                    Text(
                      friend.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (multiSelect)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(
                  ContactPickItem(
                    id: id,
                    name: displayName,
                    avatarUrl: friend.faceUrl,
                    isGroup: false,
                  ),
                ),
                activeColor: context.appColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItem(BuildContext context, Group group) {
    final id = group.groupId;
    final isSelected = selectedIds.contains(id);

    return InkWell(
      onTap: () => onToggle(
        ContactPickItem(
          id: id,
          name: group.groupName,
          avatarUrl: group.faceUrl,
          isGroup: true,
        ),
      ),
      child: Container(
        color: context.appColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar.fromUser(
              user: User(
                id: id,
                name: group.groupName,
                avatar: group.faceUrl.isNotEmpty ? group.faceUrl : null,
              ),
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${group.memberCount}人',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (multiSelect)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(
                  ContactPickItem(
                    id: id,
                    name: group.groupName,
                    avatarUrl: group.faceUrl,
                    isGroup: true,
                  ),
                ),
                activeColor: context.appColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== 预览 ====================

/// 联系人选择器的惰性构建条目（分区标题 / 好友 / 群组）。
sealed class _ContactPickerRow {
  const _ContactPickerRow();
}

class _ContactPickerSection extends _ContactPickerRow {
  const _ContactPickerSection(this.title, this.count);

  final String title;
  final int count;
}

class _ContactPickerFriend extends _ContactPickerRow {
  const _ContactPickerFriend(this.friend);

  final Friend friend;
}

class _ContactPickerGroup extends _ContactPickerRow {
  const _ContactPickerGroup(this.group);

  final Group group;
}

@AppThemePreview(name: '联系人选择列表（多选）', group: 'ContactPickerList')
Widget contactPickerListPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      height: 480,
      child: ContactPickerList(
        friends: fakeFriendList(),
        groups: [fakeGroup()],
        keyword: '',
        multiSelect: true,
        selectedIds: const {'user_2'},
        onToggle: (_) {},
      ),
    ),
  );
}
