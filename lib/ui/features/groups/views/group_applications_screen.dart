import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/group_application.dart';
import '../../../../models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';

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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('群申请'),
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
      color: AppTheme.backgroundColor,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
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
      color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                if (apply.reason.isNotEmpty)
                  Text(
                    apply.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
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
                  child: const Text(
                    '拒绝',
                    style: TextStyle(color: AppTheme.unreadRed),
                  ),
                ),
              ],
            )
          else
            Text(
              apply.handleResult == 1 ? '已接受' : '已拒绝',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSentItem(GroupApplication apply) {
    final name = apply.nickname.isNotEmpty ? apply.nickname : apply.userId;
    return Container(
      color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
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
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
      ),
    );
  }
}
