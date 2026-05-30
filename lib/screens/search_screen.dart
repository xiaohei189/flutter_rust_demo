import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/message_service_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../src/rust/infra/database/models.dart' show LocalConversation;
import '../widgets/chat_list_item.dart';

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _query = _controller.text.trim());
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

  List<LocalConversation> get _searchResults {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    final conversations = ref.read(messageServiceProvider).conversations;

    switch (_activeCategory) {
      case _SearchCategory.message:
        return conversations.where((c) {
          final name = c.showName.isNotEmpty ? c.showName : c.conversationId;
          return name.toLowerCase().contains(q) ||
              c.latestMsg.toLowerCase().contains(q);
        }).toList();
      case _SearchCategory.contacts:
        return conversations.where((c) {
          if (c.conversationType != 1) return false;
          final name = c.showName.isNotEmpty ? c.showName : c.conversationId;
          return name.toLowerCase().contains(q);
        }).toList();
      case _SearchCategory.groups:
        return conversations.where((c) {
          if (c.conversationType != 2 && c.conversationType != 3) return false;
          final name = c.showName.isNotEmpty ? c.showName : c.conversationId;
          return name.toLowerCase().contains(q);
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _searchResults;

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
                          color: AppTheme.textSecondaryColor
                              .withValues(alpha: 0.8),
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
                        () => _activeCategory = _SearchCategory.message),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: '联系人',
                    isSelected: _activeCategory == _SearchCategory.contacts,
                    onTap: () => setState(
                        () => _activeCategory = _SearchCategory.contacts),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: '群组',
                    isSelected: _activeCategory == _SearchCategory.groups,
                    onTap: () => setState(
                        () => _activeCategory = _SearchCategory.groups),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            // 内容区
            Expanded(
              child: _query.isEmpty
                  ? _buildEmptyHint()
                  : results.isEmpty
                      ? _buildNoResults()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final conversation = results[index];
                            return ChatListItem(
                              key: ValueKey<String>(
                                  conversation.conversationId),
                              conversation: conversation,
                              itemIndex: index,
                              currentUserId:
                                  ref.read(messageServiceProvider).currentUserId.isNotEmpty
                                      ? ref.read(messageServiceProvider).currentUserId
                                      : null,
                              onTap: () {
                                AppRouter.goToChatDetail(context, conversation);
                              },
                            );
                          },
                        ),
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
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryColor,
            ),
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
              ? Border.all(color: AppTheme.textSecondaryColor.withValues(alpha: 0.3))
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
