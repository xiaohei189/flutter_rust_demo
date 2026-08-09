import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../domain/models/user.dart';
import '../../../../providers/user_profile_provider.dart';
import '../../../../router/app_router.dart';
import 'qr_code_screen.dart';
import '../../../../src/rust/ffi/message_media.dart' show uploadFile;
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/utils/app_logger.dart';
import '../../../../ui/core/widgets/card_layout.dart';
import '../../../../ui/core/widgets/list_row.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../view_models/user_profile_view_model.dart';

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
    // 页面加载时自动获取用户资料（会同时加载本地头像路径）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadProfile();
    });
  }

  User _buildCurrentUser(UserProfileState state) {
    // 使用 Provider 中的显示头像 URL（自动处理本地路径和服务器 URL 的优先级）
    final avatarUrl = ref.read(userProfileProvider.notifier).getDisplayAvatarUrl();
    return User(
      id: state.profile?.userId ?? '',
      name: state.nickname.isNotEmpty ? state.nickname : '未设置',
      avatar: avatarUrl,
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

  Future<void> _pickImage() async {
    appLog.i('[MyProfile] 开始选择图片...');
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      appLog.i('[MyProfile] 用户取消选择图片');
      return;
    }

    appLog.i('[MyProfile] 选择图片成功: ${image.path}');
    appLog.i('[MyProfile] 文件是否存在: ${File(image.path).existsSync()}');

    if (!mounted) return;

    // 先设置本地路径并持久化，立即显示预览
    await ref.read(userProfileProvider.notifier).setLocalAvatarPath(image.path);
    appLog.i('[MyProfile] 已保存本地头像路径到 Provider');

    try {
      appLog.i('[MyProfile] 开始上传文件...');
      // 上传文件到服务器
      final url = await uploadFile(filePath: image.path, fileName: 'avatar.jpg');
      appLog.i('[MyProfile] 上传完成，返回 URL: $url');

      // 检查 URL 是否有效（不为空且非示例地址）
      final isValidUrl = url.isNotEmpty && !url.contains('example.com');
      appLog.i('[MyProfile] URL 是否有效: $isValidUrl');

      // 更新服务器头像 URL（用于持久化）
      appLog.i('[MyProfile] 开始更新服务器头像...');
      final success = await ref.read(userProfileProvider.notifier).updateAvatar(url);
      appLog.i('[MyProfile] 服务器更新结果: $success');

      if (!mounted) return;

      if (success && isValidUrl) {
        // 服务器返回有效 URL，本地路径已保留作为备份
        appLog.i('[MyProfile] 服务器 URL 有效，保留本地路径作为备份');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );
      } else {
        // 服务器更新失败或 URL 无效
        appLog.w('[MyProfile] 服务器更新失败或 URL 无效，保留本地路径');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传失败')),
        );
      }
    } catch (e, stackTrace) {
      appLog.e('[MyProfile] 上传失败: $e');
      appLog.e('[MyProfile] 堆栈: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
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
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      const SizedBox(height: 12),
                // 基本信息卡片
                CardLayout(
                  children: [
                    // 头像
                    ListRow(
                      label: '头像',
                      trailing: UserAvatar(user: currentUser, radius: 20),
                      onTap: _pickImage,
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
                    // 手机号
                    ListRow(
                      label: '手机号',
                      value: state.profile?.telephone.isNotEmpty == true ? state.profile!.telephone : '未绑定',
                      valueColor: AppTheme.textSecondaryColor,
                      onTap: null,
                    ),
                    const ListDivider(),
                    // User ID
                    ListRow(
                      label: 'User ID',
                      value: state.profile?.userId ?? '未设置',
                      valueColor: AppTheme.textSecondaryColor,
                      onTap: null,
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
                      onTap: () {
                        final userId = state.profile?.userId ?? '';
                        if (userId.isEmpty) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QrCodeScreen(
                              title: '我的二维码',
                              data: userId,
                              subtitle: state.nickname,
                            ),
                          ),
                        );
                      },
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
