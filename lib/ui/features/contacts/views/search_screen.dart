import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/group.dart';
import '../../../../domain/models/friend_search_result.dart';
import '../../../../models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../src/rust/model/local.dart' show LocalChatLog;
import '../../../../widgets/user_avatar.dart';

/// 搜索分类
enum _SearchCategory { message, contacts, groups }

/// 全屏搜索页面（参考飞书风格）
/// 顶部：搜索输入框 + 取消按钮
/// 分类 Tab：消息、联系人、群组
/// 内容区：搜索结果或空状态提示
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  _SearchCategory _activeCategory = _SearchCategory.message;
  bool _searching = false;
  String? _error;
  List<LocalChatLog> _messageResults = const [];
  List<FriendSearchResult> _friendResults = const [];
  List<Group> _groupResults = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final q = _controller.text.trim();
      setState(() => _query = q);
      unawaited(_search(q));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _error = null;
        _messageResults = const [];
        _friendResults = const [];
        _groupResults = const [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      switch (_activeCategory) {
        case _SearchCategory.message:
          final svc = ref.read(messageServiceProvider.notifier);
          final conversations = ref.read(messageServiceProvider).conversations;
          final all = <LocalChatLog>[];
          for (final c in conversations.take(50)) {
            try {
              all.addAll(
                await svc.searchLocalMessages(
                  conversationId: c.conversationId,
                  keyword: query,
                  count: 5,
                ),
              );
            } catch (_) {}
          }
          _messageResults = all;
        case _SearchCategory.contacts:
          _friendResults = await ref
              .read(friendSearchRepositoryProvider)
              .search(query);
        case _SearchCategory.groups:
          _groupResults = await ref
              .read(groupRepositoryProvider)
              .searchGroups(query);
      }
    } catch (e) {
      _error = '搜索失败: $e';
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏 + 取消
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: '搜索',
                        hintStyle: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 22,
                          color: AppTheme.textSecondaryColor.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _controller.clear(),
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
                    ),
                  ),
                  TextButton(
                    onPressed: () => AppRouter.goBack(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 分类 Tab
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  _CategoryChip(
                    label: '消息',
                    isSelected: _activeCategory == _SearchCategory.message,
                    onTap: () => setState(
                      () => _activeCategory = _SearchCategory.message,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: '联系人',
                    isSelected: _activeCategory == _SearchCategory.contacts,
                    onTap: () => setState(
                      () => _activeCategory = _SearchCategory.contacts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: '群组',
                    isSelected: _activeCategory == _SearchCategory.groups,
                    onTap: () => setState(
                      () => _activeCategory = _SearchCategory.groups,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            // 内容区
            Expanded(
              child: _query.isEmpty ? _buildEmptyHint() : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 80,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '输入关键词进行查询',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到「$_query」相关结果',
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(color: AppTheme.unreadRed),
          ),
        ),
      );
    }

    switch (_activeCategory) {
      case _SearchCategory.message:
        if (_messageResults.isEmpty) return _buildNoResults();
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _messageResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
          itemBuilder: (_, i) => _buildMessageItem(_messageResults[i]),
        );
      case _SearchCategory.contacts:
        if (_friendResults.isEmpty) return _buildNoResults();
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _friendResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
          itemBuilder: (_, i) => _buildFriendItem(_friendResults[i]),
        );
      case _SearchCategory.groups:
        if (_groupResults.isEmpty) return _buildNoResults();
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _groupResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
          itemBuilder: (_, i) => _buildGroupItem(_groupResults[i]),
        );
    }
  }

  Widget _buildMessageItem(LocalChatLog log) {
    return ListTile(
      leading: UserAvatar(
        user: User(
          id: log.sendId,
          name: log.senderNickName,
          avatar: log.senderFaceUrl.isNotEmpty ? log.senderFaceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(log.content, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        log.senderNickName.isNotEmpty ? log.senderNickName : log.sendId,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildFriendItem(FriendSearchResult item) {
    final name = item.nickname.isNotEmpty ? item.nickname : item.userId;
    return ListTile(
      leading: UserAvatar(
        user: User(
          id: item.userId,
          name: name,
          avatar: item.faceUrl.isNotEmpty ? item.faceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.remark.isNotEmpty ? item.remark : 'ID: ${item.userId}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => AppRouter.goToUserProfile(
        context,
        userId: item.userId,
        user: User(
          id: item.userId,
          name: name,
          avatar: item.faceUrl.isNotEmpty ? item.faceUrl : null,
        ),
      ),
    );
  }

  Widget _buildGroupItem(Group group) {
    return ListTile(
      leading: UserAvatar(
        user: User(
          id: group.groupId,
          name: group.groupName,
          avatar: group.faceUrl.isNotEmpty ? group.faceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(
        group.groupName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${group.memberCount}人',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => AppRouter.goToGroupInfoById(context, group.groupId),
    );
  }
}

/// 搜索分类 chip
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            color: isSelected
                ? AppTheme.textPrimaryColor
                : AppTheme.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}
