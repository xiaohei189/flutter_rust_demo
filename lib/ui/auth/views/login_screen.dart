import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/auth.dart' show VerificationCodeUsage;
import '../../../../core/utils/app_logger.dart';
import '../../../../router/app_paths.dart';
import '../../../../router/app_router.dart';
import '../providers/auth_provider.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// 登录页：支持密码登录与验证码登录，与 openim-flutter-demo 对齐。
/// 业务逻辑由 [AuthViewModel] 负责，页面只做表单与导航。
class LoginScreen extends ConsumerStatefulWidget {
  final String wsUrl;
  final String apiBaseUrl;

  const LoginScreen({
    super.key,
    this.wsUrl = 'ws://localhost:10001',
    this.apiBaseUrl = 'http://localhost:10002',
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loggedFirstBuild = false;

  @override
  void initState() {
    super.initState();
    appLog.i(
      '[LoginMeasure] T2 登录页 init ',
    );
  }
  final _areaCodeController = TextEditingController(text: '+86');
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscurePassword = true;
  bool _isVerifyCodeLogin = false; // false=密码登录 true=验证码登录

  @override
  void dispose() {
    _areaCodeController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _areaCode => _areaCodeController.text.trim().isEmpty
      ? '+86'
      : _areaCodeController.text.trim();
  String get _phone => _phoneController.text.trim();

  Future<void> _sendCode() async {
    await ref
        .read(authViewModelProvider.notifier)
        .sendCode(
          areaCode: _areaCode,
          phoneNumber: _phone,
          usedFor: VerificationCodeUsage.login,
        );
  }

  Future<void> _loginWithPassword() async {
    final ok = await ref
        .read(authViewModelProvider.notifier)
        .loginWithPassword(
          areaCode: _areaCode,
          phoneNumber: _phone,
          password: _passwordController.text.trim(),
          wsUrl: widget.wsUrl,
          apiBaseUrl: widget.apiBaseUrl,
        );
    if (ok && mounted) {
      context.go(AppPaths.main);
    }
  }

  Future<void> _loginWithVerifyCode() async {
    final ok = await ref
        .read(authViewModelProvider.notifier)
        .loginWithVerifyCode(
          areaCode: _areaCode,
          phoneNumber: _phone,
          verifyCode: _codeController.text.trim(),
          wsUrl: widget.wsUrl,
          apiBaseUrl: widget.apiBaseUrl,
        );
    if (ok && mounted) {
      context.go(AppPaths.main);
    }
  }

  void _login() {
    if (_isVerifyCodeLogin) {
      _loginWithVerifyCode();
    } else {
      _loginWithPassword();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedFirstBuild) {
      _loggedFirstBuild = true;
      appLog.i(
        '[LoginMeasure] T3 登录页首帧 build ',
      );
    }
    final authState = ref.watch(authViewModelProvider);
    final loading = authState.isLoading;
    final countdown = authState.countdown;
    final errorText = authState.errorText;
    final colors = context.appColors;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)?.loginTitle ?? '欢迎使用',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('密码登录')),
                    ButtonSegment(value: true, label: Text('验证码登录')),
                  ],
                  selected: {_isVerifyCodeLogin},
                  onSelectionChanged: (s) {
                    setState(() => _isVerifyCodeLogin = s.first);
                    ref.read(authViewModelProvider.notifier).clearError();
                  },
                ),
                const SizedBox(height: 24),
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
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('login_phone'),
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
                if (_isVerifyCodeLogin) ...[
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
                ] else
                  TextFormField(
                    key: const ValueKey('login_password'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    onChanged: (_) =>
                        ref.read(authViewModelProvider.notifier).clearError(),
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
                  key: const ValueKey('login_submit'),
                  onPressed: loading ? null : _login,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        AppRouter.goToRegister(
                          context,
                          wsUrl: widget.wsUrl,
                          apiBaseUrl: widget.apiBaseUrl,
                        );
                      },
                      child: const Text('注册账号'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _isVerifyCodeLogin = true);
                        ref.read(authViewModelProvider.notifier).clearError();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('当前为验证码登录，获取验证码后即可登录'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('忘记密码'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
