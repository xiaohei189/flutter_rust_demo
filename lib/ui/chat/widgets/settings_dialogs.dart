import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/user.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../contacts/providers/friend_provider.dart';

/// 确认退出群组。
Future<bool> confirmQuitGroup(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('退出群组'),
      content: const Text('确定要退出该群组吗？退出后将无法接收群消息。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('退出', style: TextStyle(color: context.appColors.danger)),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

/// 确认清空聊天记录。
Future<bool> confirmClearChatHistory(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清空聊天记录'),
      content: const Text('确定要清空该会话的所有聊天记录吗？此操作不可恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('清空', style: TextStyle(color: context.appColors.danger)),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

/// 群昵称/群公告编辑弹窗，返回输入文本。
Future<String?> showChatSettingsTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initialValue = '',
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// 邀请成员底部面板：选择好友后回调 [onInvite]。
Future<void> showInviteMemberSheet(
  BuildContext context, {
  required Future<void> Function(List<String>) onInvite,
}) {
  final selectedIds = <String>[];
  return showModalBottomSheet(
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
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Consumer(
                builder: (context, ref, _) {
                  final friendState = ref.watch(friendListProvider);

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
                              '邀请成员',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: selectedIds.isEmpty
                                  ? null
                                  : () async {
                                      Navigator.of(context).pop();
                                      await onInvite(selectedIds);
                                    },
                              child: Text(
                                '确定 (${selectedIds.length})',
                                style: TextStyle(
                                  color: selectedIds.isEmpty
                                      ? context.appColors.textSecondary
                                      : context.appColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
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
                                  final isSelected = selectedIds.contains(
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
                                    trailing: Checkbox(
                                      value: isSelected,
                                      activeColor: context.appColors.primary,
                                      onChanged: (checked) {
                                        setSheetState(() {
                                          if (checked == true) {
                                            selectedIds.add(friend.userId);
                                          } else {
                                            selectedIds.remove(friend.userId);
                                          }
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setSheetState(() {
                                        if (isSelected) {
                                          selectedIds.remove(friend.userId);
                                        } else {
                                          selectedIds.add(friend.userId);
                                        }
                                      });
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
    },
  );
}
