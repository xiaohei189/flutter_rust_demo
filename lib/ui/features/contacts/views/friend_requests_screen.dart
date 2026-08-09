import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/friend_application.dart';
import '../../../../models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';

/// 好友申请页面
///
/// 包含两个区域：
/// - 收到的申请：可处理（接受/拒绝）
/// - 我发出的申请：显示等待状态
class FriendRequestsScreen extends ConsumerStatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  ConsumerState<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendApplyProvider.notifier).loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendApplyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('好友申请'), elevation: 0),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(friendApplyProvider.notifier).loadApplications(),
              child: ListView(
                children: [
                  // 收到的申请
                  _buildSectionHeader('收到的申请', count: state.received.length),
                  if (state.received.isEmpty)
                    _buildEmptyHint('暂无收到的好友申请')
                  else
                    ...state.received.map((apply) => _buildReceivedItem(apply)),

                  const SizedBox(height: 12),

                  // 我发出的申请
                  _buildSectionHeader('我发出的申请', count: state.sent.length),
                  if (state.sent.isEmpty)
                    _buildEmptyHint('暂无发出的好友申请')
                  else
                    ...state.sent.map((apply) => _buildSentItem(apply)),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  /// 构建分区标题
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

  /// 构建收到的申请项
  Widget _buildReceivedItem(FriendApplication apply) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 头像
          UserAvatar(
            user: User(
              id: apply.userId,
              name: apply.nickname,
              avatar: apply.faceUrl,
            ),
            radius: 22,
          ),
          const SizedBox(width: 12),
          // 昵称 + 验证消息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apply.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (apply.reqMsg != null && apply.reqMsg!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    apply.reqMsg!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 状态按钮
          _buildReceivedStatusButton(apply),
        ],
      ),
    );
  }

  /// 构建收到的申请状态按钮
  Widget _buildReceivedStatusButton(FriendApplication apply) {
    switch (apply.handleResult) {
      case 0:
        // 未处理 -> 显示"处理"按钮
        return TextButton(
          onPressed: () => _showHandleDialog(apply.userId),
          style: TextButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('处理', style: TextStyle(fontSize: 13)),
        );
      case 1:
        // 已同意
        return const Text(
          '已同意',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF34C759),
            fontWeight: FontWeight.w500,
          ),
        );
      case 2:
        // 已拒绝
        return const Text(
          '已拒绝',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 构建发出的申请项
  Widget _buildSentItem(FriendApplication apply) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 头像
          UserAvatar(
            user: User(
              id: apply.userId,
              name: apply.nickname,
              avatar: apply.faceUrl,
            ),
            radius: 22,
          ),
          const SizedBox(width: 12),
          // 昵称 + 验证消息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apply.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (apply.reqMsg != null && apply.reqMsg!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    apply.reqMsg!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 状态
          _buildSentStatus(apply),
        ],
      ),
    );
  }

  /// 构建发出的申请状态
  Widget _buildSentStatus(FriendApplication apply) {
    switch (apply.handleResult) {
      case 0:
        // 等待验证
        return const Text(
          '等待验证',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        );
      case 1:
        // 已同意
        return const Text(
          '已同意',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF34C759),
            fontWeight: FontWeight.w500,
          ),
        );
      case 2:
        // 已拒绝
        return const Text(
          '已拒绝',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 构建空状态提示
  Widget _buildEmptyHint(String message) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ),
    );
  }

  /// 显示处理对话框（接受/拒绝）
  void _showHandleDialog(String userId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('处理好友申请'),
        content: const Text('请选择操作'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final ok = await ref
                  .read(friendApplyProvider.notifier)
                  .refuseApplication(userId);
              if (!mounted) return;
              _showApplyFeedback(ok, '已拒绝好友申请', '拒绝好友申请失败');
            },
            child: const Text(
              '拒绝',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final ok = await ref
                  .read(friendApplyProvider.notifier)
                  .acceptApplication(userId);
              if (!mounted) return;
              _showApplyFeedback(ok, '已接受好友申请', '接受好友申请失败');
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  void _showApplyFeedback(bool ok, String success, String failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? success : failure),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
