import 'package:flutter/material.dart';

import '../models/user.dart';
import '../router/app_router.dart';
import '../services/navigation_service.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../theme/app_theme.dart';
import '../widgets/card_layout.dart';
import '../widgets/list_row.dart';
import '../widgets/user_avatar.dart';

/// 群信息页面：群头像（可编辑）、群名称（可编辑）、群描述（可编辑）、群二维码（只读）
class GroupInfoScreen extends StatefulWidget {
  final im_conv.LocalConversation conversation;

  const GroupInfoScreen({super.key, required this.conversation});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late String _groupName;
  late String _groupDescription;

  String get _groupId =>
      widget.conversation.groupId.isNotEmpty
          ? widget.conversation.groupId
          : widget.conversation.conversationId;

  User get _groupUser => User(
        id: _groupId,
        name: _groupName,
        avatar: widget.conversation.faceUrl.isNotEmpty
            ? widget.conversation.faceUrl
            : null,
      );

  @override
  void initState() {
    super.initState();
    _groupName = widget.conversation.showName.isNotEmpty
        ? widget.conversation.showName
        : '群聊';
    _groupDescription = '暂无描述';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('群信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // 群头像、群名称、群描述
          CardLayout(
            children: [
              ListRow(
                label: '群头像',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(user: _groupUser, radius: 22),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                onTap: () {
                  // TODO: 选择/更换群头像
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('更换群头像功能开发中'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const ListDivider(),
              TwoLineListRow(
                label: '群名称',
                value: _groupName,
                onTap: () => _editField(
                  title: '修改群名称',
                  initialValue: _groupName,
                  onSave: (val) => setState(() => _groupName = val),
                ),
              ),
              const ListDivider(),
              TwoLineListRow(
                label: '群描述',
                value: _groupDescription,
                onTap: () => _editField(
                  title: '修改群描述',
                  initialValue: _groupDescription == '暂无描述' ? '' : _groupDescription,
                  onSave: (val) => setState(
                    () => _groupDescription = val.isEmpty ? '暂无描述' : val,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 群二维码（只读）
          CardLayout(
            children: [
              ListRow(
                label: '群二维码',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      size: 22,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                onTap: () {
                  // TODO: 展示群二维码大图
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('群二维码功能开发中'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _editField({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '请输入$title',
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => NavigationService.instance.goBack(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) onSave(text);
              NavigationService.instance.goBack();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
