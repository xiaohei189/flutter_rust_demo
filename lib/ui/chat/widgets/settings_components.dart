import 'package:flutter/material.dart';

import '../../../domain/models/user.dart';
import '../../../domain/models/group_member.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';

/// 聊天设置分区卡片。
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      color: context.appColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 聊天设置分区标题。
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

/// 聊天设置导航行。
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({super.key, required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: context.appColors.textPrimary,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.appColors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// 聊天设置开关行。
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: context.appColors.textPrimary,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.appColors.primary,
          ),
        ],
      ),
    );
  }
}

/// 群成员头像。
class RealMemberAvatar extends StatelessWidget {
  const RealMemberAvatar({super.key, required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final displayName = member.nickname.isNotEmpty
        ? member.nickname
        : member.userId;
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
            style: TextStyle(
              fontSize: 11,
              color: context.appColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// 添加群成员按钮。
class AddMemberButton extends StatelessWidget {
  const AddMemberButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: context.appColors.divider),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.add,
              color: context.appColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加',
            style: TextStyle(
              fontSize: 11,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
