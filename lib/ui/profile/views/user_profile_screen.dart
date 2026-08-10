import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/contacts/views/friend_setup_screen.dart';
import '../../../../data/services/services.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../ui/core/utils/app_logger.dart';
import '../view_models/user_profile_view_model.dart';

/// 用户个人信息页面：从聊天气泡头像点击进入
class UserProfileScreen extends ConsumerStatefulWidget {
  final User user;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.isCurrentUser = false,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  UserInfo? _userProfile;
  bool _isLoading = false;
  bool _isFriend = false;
  bool _isSelf = false;
  Map<String, String> _exData = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final userProfileState = ref.read(userProfileProvider);
      if (userProfileState.profile != null && 
          userProfileState.profile!.userId == widget.user.id) {
        _userProfile = userProfileState.profile;
        _exData = UserProfileState.parseEx(_userProfile?.remark);
      } else {
        _userProfile = await ref
            .read(userProfileRepositoryProvider)
            .fetchProfile(widget.user.id);
        _exData = UserProfileState.parseEx(_userProfile?.remark);
      }

      // 判断是否是自己
      _isSelf = ref
          .read(userProfileRepositoryProvider)
          .isCurrentUser(widget.user.id);

      // 判断是否是好友（非自己时才检查）
      if (!_isSelf) {
        try {
          _isFriend = await ref
              .read(userProfileRepositoryProvider)
              .isFriend(widget.user.id);
        } catch (e) {
          appLog.e('[UserProfileScreen] 检查好友关系失败: $e');
          _isFriend = false;
        }
      }
    } catch (e) {
      appLog.e('[UserProfileScreen] 加载用户资料失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取最新的用户信息
    final userProfileState = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);
    
    // 总是使用最新的用户信息
    User displayUser = widget.user;
    UserInfo? displayProfile = _userProfile;
    
    // 如果是当前用户，优先使用 provider 中的信息
    if (userProfileState.profile != null && 
        userProfileState.profile!.userId == widget.user.id) {
      displayProfile = userProfileState.profile;
      final avatarUrl = notifier.getDisplayAvatarUrl();
      displayUser = User(
        id: userProfileState.profile!.userId,
        name: userProfileState.profile!.nickname,
        avatar: avatarUrl,
        status: widget.user.status,
      );
    }
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('个人信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                // 头像 + 基本信息卡片
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      UserAvatar(user: displayUser, radius: 44),
                      const SizedBox(height: 16),
                      Text(
                        displayUser.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: displayUser.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已复制 ID'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: ${displayUser.id}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_outlined,
                              size: 14,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                      if (displayUser.status != null && displayUser.status!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          displayUser.status!,
                          style: TextStyle(
                            fontSize: 13,
                            color: displayUser.status == '在线'
                                ? const Color(0xFF34C759)
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 基本信息列表
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('用户名称', displayProfile?.nickname ?? displayUser.name),
                      _buildDivider(),
                      _buildInfoRow('用户 ID', displayUser.id),
                      if (_exData['alias'] != null && _exData['alias']!.isNotEmpty) ...[
                        _buildDivider(),
                        _buildInfoRow('别名', _exData['alias']!),
                      ],
                      if (_exData['signature'] != null && _exData['signature']!.isNotEmpty) ...[
                        _buildDivider(),
                        _buildInfoRow('个性签名', _exData['signature']!),
                      ],
                      if (displayProfile != null && displayProfile.remark.isNotEmpty && 
                          _exData['alias'] == null && _exData['signature'] == null) ...[
                        _buildDivider(),
                        _buildInfoRow('备注信息', displayProfile.remark),
                      ],
                      if (displayUser.avatar != null && displayUser.avatar!.isNotEmpty) ...[
                        _buildDivider(),
                        _buildInfoRow('头像状态', '已设置'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 高级信息列表
                if (displayProfile != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('消息接收设置', _formatRecvMsgOpt(displayProfile.globalRecvMsgOpt)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // 操作按钮
                if (_isSelf)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          Icons.edit_outlined,
                          '编辑资料',
                          () => NavigationService.instance.goBack(),
                        ),
                      ],
                    ),
                  )
                else if (_isFriend)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          Icons.chat_bubble_outline,
                          '发消息',
                          () => NavigationService.instance.goBack(),
                        ),
                        _buildDivider(),
                        _buildActionRow(
                          context,
                          Icons.settings_outlined,
                          '好友设置',
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FriendSetupScreen(
                                  userId: widget.user.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          context,
                          Icons.person_add_outlined,
                          '添加好友',
                          () => _showAddFriendDialog(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _formatRecvMsgOpt(int opt) {
    switch (opt) {
      case 0:
        return '接收所有消息';
      case 1:
        return '仅接收好友消息';
      case 2:
        return '不接收任何消息';
      default:
        return '未知 ($opt)';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.primaryColor,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加好友'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '输入验证消息（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final reqMsg = controller.text.trim();
                Navigator.of(context).pop();
                try {
                  await ref
                      .read(userProfileRepositoryProvider)
                      .sendFriendRequest(
                        widget.user.id,
                        reqMsg,
                      );
                  if (mounted) {
                    setState(() => _isFriend = true);
                  }
                  NavigationService.instance.showSnackBar('好友申请已发送');
                } catch (e) {
                  appLog.e('[UserProfileScreen] 添加好友失败: $e');
                  NavigationService.instance.showSnackBar('添加好友失败: $e');
                }
              },
              child: const Text('发送'),
            ),
          ],
        );
      },
    );
  }
}
