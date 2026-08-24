import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/auth.dart' show VerificationCodeUsage;
import '../../../../l10n/app_localizations.dart';
import '../../../../router/app_paths.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// 注册页：手机号 + 验证码 + 昵称，注册成功后自动登录。
/// 业务逻辑由 [AuthViewModel] 负责，页面只做表单与导航。
class RegisterScreen extends ConsumerStatefulWidget {
  final String wsUrl;
  final String apiBaseUrl;

  const RegisterScreen({
    super.key,
    required this.wsUrl,
    required this.apiBaseUrl,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaCodeController = TextEditingController(text: '+86');
  final _phoneController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _codeController = TextEditingController();

  String get _areaCode => _areaCodeController.text.trim().isEmpty
      ? '+86'
      : _areaCodeController.text.trim();
  String get _phone => _phoneController.text.trim();

  @override
  void dispose() {
    _areaCodeController.dispose();
    _phoneController.dispose();
    _nicknameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    await ref
        .read(authViewModelProvider.notifier)
        .sendCode(
          areaCode: _areaCode,
          phoneNumber: _phone,
          usedFor: VerificationCodeUsage.register,
        );
  }

  Future<void> _register() async {
    final ok = await ref
        .read(authViewModelProvider.notifier)
        .register(
          areaCode: _areaCode,
          phoneNumber: _phone,
          nickname: _nicknameController.text.trim(),
          verifyCode: _codeController.text.trim(),
          wsUrl: widget.wsUrl,
          apiBaseUrl: widget.apiBaseUrl,
        );
    if (ok && mounted) {
      context.go(AppPaths.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final loading = authState.isLoading;
    final countdown = authState.countdown;
    final errorText = authState.errorText;
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.registerTitle ?? '注册账号'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: TextFormField(
                        controller: _areaCodeController,
                        decoration: const InputDecoration(
                          labelText: '区号',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: '手机号',
                          hintText: '请输入手机号',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => ref
                            .read(authViewModelProvider.notifier)
                            .clearError(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    hintText: '请输入昵称',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) =>
                      ref.read(authViewModelProvider.notifier).clearError(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: '验证码',
                          hintText: '请输入验证码',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => ref
                            .read(authViewModelProvider.notifier)
                            .clearError(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: FilledButton.tonal(
                        onPressed: (countdown > 0 || loading)
                            ? null
                            : _sendCode,
                        child: countdown > 0
                            ? Text('$countdown s 后重发')
                            : const Text('获取验证码'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '测试环境：请先点击「获取验证码」，再输入 666666',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText,
                    style: TextStyle(color: colors.danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : _register,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('注册并登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
