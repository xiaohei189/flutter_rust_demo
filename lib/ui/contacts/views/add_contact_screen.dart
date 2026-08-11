import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/friend_search_result.dart';
import '../../../../providers/providers.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../domain/models/user.dart';

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
      appBar: AppBar(title: const Text('添加好友'), elevation: 0),
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
                      hintStyle: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: context.appColors.textSecondary,
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
                      fillColor: context.appColors.background,
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
                  icon: Icon(Icons.search, color: context.appColors.primary),
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
  Widget _buildSearchResultItem(FriendSearchResult item) {
    final isSelf = item.relationship == 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 头像
          UserAvatar(
            user: User(
              id: item.userId,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.remark.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '备注: ${item.remark}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.textSecondary,
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
              backgroundColor: isSelf
                  ? Colors.grey.shade200
                  : context.appColors.primary,
              foregroundColor: isSelf
                  ? context.appColors.textSecondary
                  : Colors.white,
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
            color: context.appColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '输入用户 ID 搜索好友',
            style: TextStyle(
              fontSize: 15,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加好友对话框
  void _showAddFriendDialog(FriendSearchResult item) {
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
                hintStyle: TextStyle(
                  color: context.appColors.textSecondary,
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
              await _sendFriendRequest(item.userId, reqMsg);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  /// 发送好友请求
  Future<void> _sendFriendRequest(String userId, String reqMsg) async {
    final ok = await ref
        .read(friendSearchProvider.notifier)
        .sendFriendRequest(userId, reqMsg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '好友申请已发送' : '发送失败'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
