import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../router/app_router.dart';
import '../services/navigation_service.dart';
import '../services/services.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../theme/app_theme.dart';
import '../widgets/card_layout.dart';
import '../widgets/list_row.dart';
import '../widgets/user_avatar.dart';

/// 群信息页面：群头像（可编辑）、群名称（可编辑）、群描述（可编辑）、群二维码（只读）
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  late String _groupName;
  late String _groupDescription;

  /// 获取会话信息
  im_conv.LocalConversation? get _conversation {
    // 先尝试从新的 ConversationService 获取
    final newService = ref.read(conversationServiceProvider);
    var conversation = newService.getConversation(widget.conversationId);
    if (conversation != null) return conversation;
    
    // 如果新服务没有，尝试从旧的 conversationListProvider 获取
    final oldState = ref.read(conversationListProvider);
    conversation = oldState.conversations
        .where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
    return conversation;
  }

  String get _groupId {
    final conversation = _conversation;
    if (conversation == null) return widget.conversationId;
    return conversation.groupId.isNotEmpty
        ? conversation.groupId
        : conversation.conversationId;
  }

  User get _groupUser {
    final conversation = _conversation;
    if (conversation == null) {
      return User(
        id: widget.conversationId,
        name: '未知群组',
        avatar: null,
      );
    }
    return User(
      id: _groupId,
      name: _groupName,
      avatar: conversation.faceUrl.isNotEmpty
          ? conversation.faceUrl
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    final conversation = _conversation;
    if (conversation != null) {
      _groupName = conversation.showName.isNotEmpty
          ? conversation.showName
          : '群聊';
    } else {
      _groupName = '群聊';
    }
    _groupDescription = '暂无描述';
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

    if (conversation == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('群信息'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => AppRouter.goBack(context),
          ),
        ),
        body: const Center(
          child: Text('群组不存在'),
        ),
      );
    }

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
