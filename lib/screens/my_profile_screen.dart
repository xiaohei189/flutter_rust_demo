import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/user_profile_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/card_layout.dart';
import '../widgets/list_row.dart';
import '../widgets/user_avatar.dart';

/// 个人信息页面（可编辑），从左侧抽屉进入
/// 头像、姓名、别名、我的二维码、个性签名、企业
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  @override
  void initState() {
    super.initState();
    // 页面加载时自动获取用户资料
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadProfile();
    });
  }

  User _buildCurrentUser(UserProfileState state) {
    return User(
      id: state.profile?.userId ?? '',
      name: state.nickname.isNotEmpty ? state.nickname : '未设置',
      avatar: state.profile?.faceUrl.isNotEmpty == true
          ? state.profile!.faceUrl
          : null,
      status: null,
    );
  }

  Future<void> _editField({
    required String title,
    required String currentValue,
    required String hint,
    required Future<bool> Function(String) onSave,
  }) async {
    final result = await context.push<String>(
      '/profile/edit-field',
      extra: {
        'title': title,
        'hint': hint,
        'initialValue': currentValue,
      },
    );
    if (result != null && mounted) {
      final success = await onSave(result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProfileProvider);
    final currentUser = _buildCurrentUser(state);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('个人信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: state.isLoading && state.profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                // 基本信息卡片
                CardLayout(
                  children: [
                    // 头像
                    ListRow(
                      label: '头像',
                      trailing: UserAvatar(user: currentUser, radius: 20),
                      onTap: () {},
                    ),
                    const ListDivider(),
                    // 姓名
                    ListRow(
                      label: '姓名',
                      value: state.nickname,
                      onTap: () => _editField(
                        title: '修改姓名',
                        currentValue: state.nickname,
                        hint: '请输入姓名',
                        onSave: (value) =>
                            ref.read(userProfileProvider.notifier).updateNickname(value),
                      ),
                    ),
                    const ListDivider(),
                    // 别名
                    ListRow(
                      label: '别名',
                      value: state.alias.isEmpty ? null : state.alias,
                      placeholder: '输入别名',
                      onTap: () => _editField(
                        title: '修改别名',
                        currentValue: state.alias,
                        hint: '请输入别名',
                        onSave: (value) =>
                            ref.read(userProfileProvider.notifier).updateAlias(value),
                      ),
                    ),
                    const ListDivider(),
                    // 我的二维码
                    ListRow(
                      label: '我的二维码',
                      trailing: const Icon(
                        Icons.qr_code_2,
                        size: 22,
                        color: AppTheme.textPrimaryColor,
                      ),
                      onTap: () {},
                    ),
                    const ListDivider(),
                    // 个性签名
                    ListRow(
                      label: '个性签名',
                      value: state.signature.isEmpty ? null : state.signature,
                      onTap: () => _editField(
                        title: '修改个性签名',
                        currentValue: state.signature,
                        hint: '请输入个性签名',
                        onSave: (value) =>
                            ref.read(userProfileProvider.notifier).updateSignature(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 企业
                CardLayout(
                  children: [
                    ListRow(
                      label: '企业',
                      value: '未认证',
                      valueColor: AppTheme.textSecondaryColor,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class ProfileFieldEditScreen extends StatefulWidget {
  const ProfileFieldEditScreen({
    super.key,
    required this.title,
    required this.hint,
    required this.initialValue,
  });

  final String title;
  final String hint;
  final String initialValue;

  @override
  State<ProfileFieldEditScreen> createState() =>
      _ProfileFieldEditScreenState();
}

class _ProfileFieldEditScreenState extends State<ProfileFieldEditScreen> {
  late final TextEditingController _controller;

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      AppRouter.goBackWithResult(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => AppRouter.goBack(context),
        ),
        actions: [
          TextButton(
            onPressed: _hasText ? _save : null,
            child: Text(
              '保存',
              style: TextStyle(
                color: _hasText ? AppTheme.primaryColor : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
