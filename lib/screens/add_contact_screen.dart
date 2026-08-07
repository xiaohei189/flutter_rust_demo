import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/friend_service.dart';
import '../src/rust/http/friend.dart' show SearchFriendItem;
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../models/user.dart';
import '../utils/app_logger.dart';

/// 添加好友 / 搜索用户页面
///
/// 顶部搜索框 + 搜索结果列表
/// 每条结果可点击"添加好友"按钮发送好友申请
class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    ref.read(friendSearchProvider.notifier).search(keyword);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加好友'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: '输入用户 ID 搜索',
                      hintStyle: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 15,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppTheme.textSecondaryColor,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(friendSearchProvider.notifier).clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onSearch(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // 搜索结果
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.results.isEmpty
                    ? _buildEmptyHint()
                    : ListView.builder(
                        itemCount: state.results.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultItem(state.results[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果项
  Widget _buildSearchResultItem(SearchFriendItem item) {
    final isSelf = item.relationship == 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 头像
          UserAvatar(
            user: User(
              id: item.friendUserId,
              name: item.nickname,
              avatar: item.faceUrl,
            ),
            radius: 22,
          ),
          const SizedBox(width: 12),
          // 昵称 + 备注
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.remark.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '备注: ${item.remark}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 添加好友按钮
          TextButton(
            onPressed: isSelf ? null : () => _showAddFriendDialog(item),
            style: TextButton.styleFrom(
              backgroundColor:
                  isSelf ? Colors.grey.shade200 : AppTheme.primaryColor,
              foregroundColor:
                  isSelf ? AppTheme.textSecondaryColor : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              isSelf ? '已是好友' : '添加好友',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '输入用户 ID 搜索好友',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加好友对话框
  void _showAddFriendDialog(SearchFriendItem item) {
    final reqMsgController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '向 ${item.nickname} 发送好友申请',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reqMsgController,
              decoration: InputDecoration(
                hintText: '请输入验证消息',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              reqMsgController.dispose();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final reqMsg = reqMsgController.text.trim();
              reqMsgController.dispose();
              await _sendFriendRequest(item.friendUserId, reqMsg);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  /// 发送好友请求
  Future<void> _sendFriendRequest(String userId, String reqMsg) async {
    final client =
        ref.read(messageServiceProvider.notifier).client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('客户端未初始化'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FriendService.instance.addFriend(
        client,
        userId: userId,
        reqMsg: reqMsg,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('好友申请已发送'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      appLog.e('[AddContactScreen] 发送好友申请失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
