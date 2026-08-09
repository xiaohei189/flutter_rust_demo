import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/app_router.dart';
import '../../../../services/auth_api.dart' show loginAsync, loginWithVerifyCode, sendVerificationCode, kAuthBaseUrl, usedForLogin;
import '../../../../ui/core/utils/app_logger.dart';
import '../../../../ui/core/utils/login_storage.dart';
import '../../../../providers/message_service_provider.dart';

/// 登录页：支持密码登录与验证码登录，与 openim-flutter-demo 对齐
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
  final _areaCodeController = TextEditingController(text: '+86');
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  bool _isVerifyCodeLogin = false; // false=密码登录 true=验证码登录
  int _countdown = 0; // 获取验证码倒计时秒数
  Timer? _countdownTimer;
  String? _errorText;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _areaCodeController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _areaCode =>
      _areaCodeController.text.trim().isEmpty ? '+86' : _areaCodeController.text.trim();
  String get _phone => _phoneController.text.trim();

  Future<void> _sendCode() async {
    if (_phone.isEmpty) {
      setState(() => _errorText = '请先输入手机号');
      return;
    }
    if (_countdown > 0) return;
    setState(() {
      _errorText = null;
      _countdown = 60;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown <= 1) {
          _countdown = 0;
          t.cancel();
        } else {
          _countdown--;
        }
      });
    });
    try {
      await sendVerificationCode(
        areaCode: _areaCode,
        phoneNumber: _phone,
        usedFor: usedForLogin,
      );
      if (mounted) setState(() => _errorText = null);
    } catch (e, st) {
      appLog.e('发送验证码失败', e, st);
      if (mounted) {
        setState(() {
          _countdown = 0;
          _countdownTimer?.cancel();
          _errorText = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
        });
      }
    }
  }

  Future<void> _loginWithPassword() async {
    final password = _passwordController.text.trim();
    if (_phone.isEmpty || password.isEmpty) {
      setState(() => _errorText = '请输入手机号和密码');
      return;
    }
    appLog.i('[登录] 密码登录开始');
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      appLog.i('[登录] 即将请求密码登录 HTTP');
      final resp = await loginAsync(
        areaCode: _areaCode,
        phoneNumber: _phone,
        password: password,
        platform: 5,
      );
      appLog.i('[登录] 密码登录 HTTP 返回成功');
      if (!mounted) return;
      appLog.i('[登录] 调用 _stopLoadingAndGoToMain');
      _stopLoadingAndGoToMain(resp.userId, resp.imToken);
    } catch (e, st) {
      appLog.e('[登录] 密码登录失败', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          final msg = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
          _errorText = '$msg\n请求地址: $kAuthBaseUrl/account/login';
        });
      }
    }
  }

  Future<void> _loginWithVerifyCode() async {
    final code = _codeController.text.trim();
    if (_phone.isEmpty || code.isEmpty) {
      setState(() => _errorText = '请输入手机号和验证码');
      return;
    }
    appLog.i('[登录] 验证码登录开始');
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      appLog.i('[登录] 即将请求验证码登录 HTTP（最多等 30s）');
      final result = await loginWithVerifyCode(
        areaCode: _areaCode,
        phoneNumber: _phone,
        verifyCode: code,
        platform: 5,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          '登录请求超时（30秒）。请检查：① 网络是否可用 ② 认证服务是否已启动\n请求地址: $kAuthBaseUrl/account/login',
        ),
      );
      appLog.i('[登录] 验证码登录 HTTP 返回成功');
      if (!mounted) return;
      appLog.i('[登录] 调用 _stopLoadingAndGoToMain');
      _stopLoadingAndGoToMain(result.userId, result.imToken);
    } catch (e, st) {
      appLog.e('[登录] 验证码登录失败', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          final msg = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
          _errorText = '$msg\n请求地址: $kAuthBaseUrl/account/login';
        });
      }
    }
  }

  /// 保存凭证并初始化 MessageService，然后跳转主界面
  void _stopLoadingAndGoToMain(String userId, String imToken) async {
    appLog.i('[登录] _stopLoadingAndGoToMain 开始');
    if (!mounted) return;
    setState(() => _loading = false);
    appLog.i('[登录] setState(_loading=false) 已调用');
    
    try {
      // 保存凭证
      await LoginStorage.saveCredentials(
        userId: userId,
        imToken: imToken,
        areaCode: _areaCode,
        phoneNumber: _phone,
      );
      appLog.i('[登录] 凭证已保存');
      
      // 初始化 MessageService
      appLog.i('[登录] 开始 MessageService.initialize');
      await ref.read(messageServiceProvider.notifier).initialize(
        wsUrl: widget.wsUrl,
        apiBaseUrl: widget.apiBaseUrl,
        userId: userId,
        imToken: imToken,
      );
      appLog.i('[登录] MessageService.initialize 完成');
      
      if (!mounted) return;
      // 初始化完成后再导航到主页
      context.go(AppRouter.main);
      appLog.i('[登录] 导航到主页已调用');
    } catch (e) {
      appLog.e('[登录] 初始化失败: $e');
      if (mounted) {
        setState(() {
          _errorText = '初始化失败: $e';
        });
      }
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
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.blue.shade400),
                const SizedBox(height: 12),
                Text(
                  '欢迎使用',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
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
                    setState(() {
                      _isVerifyCodeLogin = s.first;
                      _errorText = null;
                    });
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
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: '手机号',
                          hintText: '请输入手机号',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() => _errorText = null),
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
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: FilledButton.tonal(
                          onPressed: (_countdown > 0 || _loading) ? null : _sendCode,
                          child: _countdown > 0
                              ? Text('${_countdown}s 后重发')
                              : const Text('获取验证码'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '测试环境：请先点击「获取验证码」，再输入 666666',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ] else
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    onChanged: (_) => setState(() => _errorText = null),
                  ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
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
                        setState(() {
                          _isVerifyCodeLogin = true;
                          _errorText = null;
                        });
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
