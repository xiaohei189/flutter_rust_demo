import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/group_application.dart';
import '../../../../domain/models/user.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../providers/group_provider.dart';

/// 群申请页面：处理收到的入群申请，查看我发出的申请。
class GroupApplicationsScreen extends ConsumerStatefulWidget {
  const GroupApplicationsScreen({super.key});

  @override
  ConsumerState<GroupApplicationsScreen> createState() =>
      _GroupApplicationsScreenState();
}

class _GroupApplicationsScreenState
    extends ConsumerState<GroupApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupApplicationProvider.notifier).loadApplications();
    });
  }

  Future<void> _handle(GroupApplication apply, bool accept) async {
    final ok = accept
        ? await ref
              .read(groupApplicationProvider.notifier)
              .acceptApplication(groupId: apply.groupId, userId: apply.userId)
        : await ref
              .read(groupApplicationProvider.notifier)
              .refuseApplication(groupId: apply.groupId, userId: apply.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '操作成功' : '操作失败'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupApplicationProvider);

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.groupApplicationsTitle ?? '群申请',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(groupApplicationProvider.notifier)
                  .loadApplications(),
              child: ListView(
                children: [
                  _buildSectionHeader('收到的申请', count: state.received.length),
                  if (state.received.isEmpty)
                    _buildEmptyHint('暂无收到的群申请')
                  else
                    ...state.received.map((a) => _buildReceivedItem(a)),
                  const SizedBox(height: 12),
                  _buildSectionHeader('我发出的申请', count: state.sent.length),
                  if (state.sent.isEmpty)
                    _buildEmptyHint('暂无发出的群申请')
                  else
                    ...state.sent.map((a) => _buildSentItem(a)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, {required int count}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: context.appColors.background,
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: context.appColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReceivedItem(GroupApplication apply) {
    final pending = apply.handleResult == 0;
    final name = apply.nickname.isNotEmpty ? apply.nickname : apply.userId;
    return Container(
      color: context.appColors.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            user: User(
              id: apply.userId,
              name: name,
              avatar: apply.faceUrl.isNotEmpty ? apply.faceUrl : null,
            ),
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '申请加入群：${apply.groupId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.textSecondary,
                  ),
                ),
                if (apply.reason.isNotEmpty)
                  Text(
                    apply.reason,
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
          const SizedBox(width: 8),
          if (pending)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _handle(apply, true),
                  child: const Text('接受'),
                ),
                TextButton(
                  onPressed: () => _handle(apply, false),
                  child: Text(
                    '拒绝',
                    style: TextStyle(color: context.appColors.danger),
                  ),
                ),
              ],
            )
          else
            Text(
              apply.handleResult == 1 ? '已接受' : '已拒绝',
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSentItem(GroupApplication apply) {
    final name = apply.nickname.isNotEmpty ? apply.nickname : apply.userId;
    return Container(
      color: context.appColors.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            user: User(
              id: apply.userId,
              name: name,
              avatar: apply.faceUrl.isNotEmpty ? apply.faceUrl : null,
            ),
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '群 ${apply.groupId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  apply.handleResult == 0
                      ? '等待处理'
                      : apply.handleResult == 1
                      ? '已通过'
                      : '已拒绝',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Container(
      color: context.appColors.onPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: context.appColors.textSecondary),
        ),
      ),
    );
  }
}
