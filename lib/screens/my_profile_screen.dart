import 'package:flutter/material.dart';

import '../main.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// 个人信息页面（可编辑），从左侧抽屉进入
/// 头像、姓名、别名、我的二维码、个性签名、企业
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late String _name;
  late String _alias;
  late String _signature;

  @override
  void initState() {
    super.initState();
    _name = messageService.currentUserId.isNotEmpty
        ? messageService.currentUserId
        : '未设置';
    _alias = '';
    _signature = '';
  }

  User get _currentUser => User(
        id: messageService.currentUserId,
        name: _name,
        avatar: null,
        status: null,
      );

  Future<void> _editField({
    required String title,
    required String currentValue,
    required String hint,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      onSave(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('个人信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
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
                  trailing: UserAvatar(user: _currentUser, radius: 20),
                  onTap: () {},
                ),
                _divider(),
                // 姓名
                _buildRow(
                  label: '姓名',
                  value: _name,
                  onTap: () => _editField(
                    title: '修改姓名',
                    currentValue: _name,
                    hint: '请输入姓名',
                    onSave: (v) => setState(() => _name = v),
                  ),
                ),
                _divider(),
                // 别名
                _buildRow(
                  label: '别名',
                  value: _alias.isEmpty ? null : _alias,
                  placeholder: '输入别名',
                  onTap: () => _editField(
                    title: '修改别名',
                    currentValue: _alias,
                    hint: '请输入别名',
                    onSave: (v) => setState(() => _alias = v),
                  ),
                ),
                _divider(),
                // 我的二维码
                _buildRow(
                  label: '我的二维码',
                  trailing: Icon(Icons.qr_code_2, size: 22,
                      color: AppTheme.textPrimaryColor),
                  onTap: () {},
                ),
                _divider(),
                // 个性签名
                _buildRow(
                  label: '个性签名',
                  value: _signature.isEmpty ? null : _signature,
                  onTap: () => _editField(
                    title: '修改个性签名',
                    currentValue: _signature,
                    hint: '请输入个性签名',
                    onSave: (v) => setState(() => _signature = v),
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
