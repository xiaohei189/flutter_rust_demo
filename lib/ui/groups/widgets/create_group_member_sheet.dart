import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/user.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';
import '../../contacts/providers/friend_provider.dart';
import '../providers/group_provider.dart';

/// 创建群聊时选择成员底部面板：好友列表搜索/勾选 + 手动输入用户 ID。
Future<void> showCreateGroupMemberSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const CreateGroupMemberSheet(),
  );
}

class CreateGroupMemberSheet extends ConsumerStatefulWidget {
  const CreateGroupMemberSheet({super.key});

  @override
  ConsumerState<CreateGroupMemberSheet> createState() =>
      _CreateGroupMemberSheetState();
}

class _CreateGroupMemberSheetState
    extends ConsumerState<CreateGroupMemberSheet> {
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(friendListProvider.notifier).loadFriends();
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);
    final currentSelected = ref.watch(createGroupProvider).selectedMemberIds;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '选择成员',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
                  ref.read(friendListProvider.notifier).searchFriends(value);
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
                                notifier.addSelectedMember(friend.userId);
                              } else {
                                notifier.removeSelectedMember(friend.userId);
                              }
                            },
                          ),
                          onTap: () {
                            final notifier = ref.read(
                              createGroupProvider.notifier,
                            );
                            if (isSelected) {
                              notifier.removeSelectedMember(friend.userId);
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
  }

  Widget _buildManualInput(List<String> currentSelected) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _manualController,
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
            final userId = _manualController.text.trim();
            if (userId.isNotEmpty && !currentSelected.contains(userId)) {
              ref.read(createGroupProvider.notifier).addSelectedMember(userId);
              _manualController.clear();
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
}
