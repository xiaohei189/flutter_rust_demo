import 'package:flutter/material.dart';

import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../theme/app_theme.dart';
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // 群头像
          _buildEditableCard(
            children: [
              _buildRow(
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
                    SnackBar(
                      content: const Text('更换群头像功能开发中'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // 群名称
              _buildTwoLineRow(
                label: '群名称',
                value: _groupName,
                onTap: () => _editField(
                  title: '修改群名称',
                  initialValue: _groupName,
                  onSave: (val) => setState(() => _groupName = val),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // 群描述
              _buildTwoLineRow(
                label: '群描述',
                value: _groupDescription,
                onTap: () => _editField(
                  title: '修改群描述',
                  initialValue: _groupDescription == '暂无描述' ? '' : _groupDescription,
                  onSave: (val) => setState(
                    () => _groupDescription = val.isEmpty ? '暂无描述' : val,
                  ),
                  maxLines: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 群二维码（只读）
          _buildEditableCard(
            children: [
              _buildRow(
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
                    SnackBar(
                      content: const Text('群二维码功能开发中'),
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

  Widget _buildEditableCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// 单行样式：标签在左，trailing 或箭头在最右
  Widget _buildRow({
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              trailing
            else
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

  /// 两行样式：标签在上，值在下一行，箭头在最右侧垂直居中
  Widget _buildTwoLineRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) onSave(text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
