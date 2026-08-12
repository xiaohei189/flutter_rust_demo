import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/user.dart';
import '../../contacts/providers/friend_provider.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../providers/group_provider.dart';
import '../view_models/create_group_view_model.dart';

/// 创建群组页面
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _groupNameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createGroupProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupNameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createGroupState = ref.watch(createGroupProvider);

    ref.listen<CreateGroupState>(createGroupProvider, (prev, next) {
      if (next.createdGroup != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群组创建成功'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(next.createdGroup);
      }
    });

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.createGroupTitle ?? '创建群组'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _groupNameController,
                      focusNode: _groupNameFocus,
                      decoration: const InputDecoration(
                        hintText: '输入群组名称',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '选择成员 (${createGroupState.selectedMemberIds.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ),
                      if (createGroupState.selectedMemberIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: createGroupState.selectedMemberIds
                                .map((userId) => _buildMemberChip(userId))
                                .toList(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            '暂未选择成员',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.appColors.textSecondary,
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: _showAddMemberDialog,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_add_outlined,
                                size: 20,
                                color: context.appColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '添加成员',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: context.appColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (createGroupState.error != null) ...[
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: context.appColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              createGroupState.error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.appColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: createGroupState.isCreating
                      ? null
                      : _handleCreateGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appColors.primary,
                    foregroundColor: context.appColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    disabledBackgroundColor: context.appColors.primary
                        .withValues(alpha: 0.5),
                  ),
                  child: createGroupState.isCreating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.appColors.onPrimary,
                          ),
                        )
                      : const Text(
                          '创建群组',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.appColors.surface,
      child: child,
    );
  }

  Widget _buildMemberChip(String userId) {
    final friends = ref.watch(friendListProvider).friends;
    final friend = friends.where((f) => f.userId == userId).firstOrNull;
    final displayName = friend != null
        ? (friend.remark.isNotEmpty ? friend.remark : friend.nickname)
        : userId;
    final avatarUrl = friend?.faceUrl;

    return InputChip(
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                displayName.substring(0, 1),
                style: TextStyle(
                  fontSize: 10,
                  color: context.appColors.primary,
                ),
              )
            : null,
      ),
      label: Text(displayName, style: const TextStyle(fontSize: 13)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () {
        ref.read(createGroupProvider.notifier).removeSelectedMember(userId);
      },
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showAddMemberDialog() {
    ref.read(friendListProvider.notifier).loadFriends();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final friendState = ref.watch(friendListProvider);
                final currentSelected = ref
                    .watch(createGroupProvider)
                    .selectedMemberIds;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '选择成员',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('完成'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索好友',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: context.appColors.background,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          ref
                              .read(friendListProvider.notifier)
                              .searchFriends(value);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildManualInput(currentSelected),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: friendState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : friendState.friends.isEmpty
                          ? Center(
                              child: Text(
                                '暂无好友',
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: friendState.friends.length,
                              itemBuilder: (context, index) {
                                final friend = friendState.friends[index];
                                final isSelected = currentSelected.contains(
                                  friend.userId,
                                );

                                return ListTile(
                                  leading: UserAvatar(
                                    user: User(
                                      id: friend.userId,
                                      name: friend.nickname,
                                      avatar: friend.faceUrl.isNotEmpty
                                          ? friend.faceUrl
                                          : null,
                                    ),
                                    radius: 20,
                                  ),
                                  title: Text(
                                    friend.remark.isNotEmpty
                                        ? friend.remark
                                        : friend.nickname,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    'ID: ${friend.userId}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.appColors.textSecondary,
                                    ),
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor: context.appColors.primary,
                                    onChanged: (checked) {
                                      final notifier = ref.read(
                                        createGroupProvider.notifier,
                                      );
                                      if (checked == true) {
                                        notifier.addSelectedMember(
                                          friend.userId,
                                        );
                                      } else {
                                        notifier.removeSelectedMember(
                                          friend.userId,
                                        );
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    final notifier = ref.read(
                                      createGroupProvider.notifier,
                                    );
                                    if (isSelected) {
                                      notifier.removeSelectedMember(
                                        friend.userId,
                                      );
                                    } else {
                                      notifier.addSelectedMember(friend.userId);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildManualInput(List<String> currentSelected) {
    final controller = TextEditingController();

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '手动输入用户 ID',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final userId = controller.text.trim();
            if (userId.isNotEmpty && !currentSelected.contains(userId)) {
              ref.read(createGroupProvider.notifier).addSelectedMember(userId);
              controller.clear();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appColors.primary,
            foregroundColor: context.appColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }

  Future<void> _handleCreateGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入群组名称'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _groupNameFocus.unfocus();
    await ref
        .read(createGroupProvider.notifier)
        .createGroup(groupName: groupName, groupType: 2);
  }
}
