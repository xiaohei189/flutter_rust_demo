import 'package:flutter/material.dart';

import '../../../../domain/models/user.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';

/// 个人信息页顶部：头像、名称、ID 复制、在线状态。
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.onCopyId,
  });

  final User user;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          UserAvatar(user: user, radius: 44),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onCopyId,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ID: ${user.id}',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy_outlined,
                  size: 14,
                  color: colors.textSecondary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          if (user.status != null && user.status!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.status!,
              style: TextStyle(
                fontSize: 13,
                color: user.status == '在线'
                    ? context.appColors.success
                    : colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 个人信息页信息卡：名称/ID/别名/签名等键值行。
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _InfoRow(label: rows[i].$1, value: rows[i].$2),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: colors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
