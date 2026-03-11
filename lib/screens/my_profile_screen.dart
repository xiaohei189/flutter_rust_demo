import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/user_profile_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // 头像
                      _buildRow(
                        label: '头像',
                        trailing: UserAvatar(user: currentUser, radius: 20),
                        onTap: () {},
                      ),
                      _divider(),
                      // 姓名
                      _buildRow(
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
                      _divider(),
                      // 别名
                      _buildRow(
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
                      _divider(),
                      // 我的二维码
                      _buildRow(
                        label: '我的二维码',
                        trailing: Icon(
                          Icons.qr_code_2,
                          size: 22,
                          color: AppTheme.textPrimaryColor,
                        ),
                        onTap: () {},
                      ),
                      _divider(),
                      // 个性签名
                      _buildRow(
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
                ),
                const SizedBox(height: 12),
                // 企业
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildRow(
                    label: '企业',
                    value: '未认证',
                    valueColor: AppTheme.textSecondaryColor,
                    onTap: () {},
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRow({
    required String label,
    String? value,
    String? placeholder,
    Widget? trailing,
    Color? valueColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              trailing
            else if (value != null)
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? AppTheme.textPrimaryColor,
                ),
              )
            else if (placeholder != null)
              Text(
                placeholder,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          maxLines: null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}
