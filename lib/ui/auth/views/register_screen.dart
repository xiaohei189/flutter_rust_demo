import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/message_service_provider.dart';
import '../../../../router/app_router.dart';
import '../../../../data/services/auth_api.dart'
    show registerWithVerifyCode, sendVerificationCode, usedForRegister;
import '../../../../ui/core/utils/app_logger.dart';
import '../../../../data/services/login_storage.dart';

/// 注册页：手机号 + 验证码 + 昵称，注册成功后自动登录。
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

  bool _loading = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  String? _errorText;

  String get _areaCode => _areaCodeController.text.trim().isEmpty
      ? '+86'
      : _areaCodeController.text.trim();
  String get _phone => _phoneController.text.trim();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _areaCodeController.dispose();
    _phoneController.dispose();
    _nicknameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phone.isEmpty) {
      setState(() => _errorText = '请先输入手机号');
      return;
    }
    if (_countdown > 0 || _loading) return;
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
        usedFor: usedForRegister,
      );
      if (mounted) setState(() => _errorText = null);
    } catch (e) {
      if (mounted) {
        setState(() {
          _countdown = 0;
          _countdownTimer?.cancel();
          _errorText = e.toString().replaceFirst(
            RegExp(r'^Exception:?\s*'),
            '',
          );
        });
      }
    }
  }

  Future<void> _register() async {
    final nickname = _nicknameController.text.trim();
    final code = _codeController.text.trim();
    if (_phone.isEmpty || code.isEmpty || nickname.isEmpty) {
      setState(() => _errorText = '请填写手机号、验证码和昵称');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final result = await registerWithVerifyCode(
        areaCode: _areaCode,
        phoneNumber: _phone,
        nickname: nickname,
        verifyCode: code,
        platform: 5,
      );
      await LoginStorage.saveCredentials(
        userId: result.userId,
        imToken: result.imToken,
        areaCode: _areaCode,
        phoneNumber: _phone,
      );
      await ref
          .read(messageServiceProvider.notifier)
          .initialize(
            wsUrl: widget.wsUrl,
            apiBaseUrl: widget.apiBaseUrl,
            userId: result.userId,
            imToken: result.imToken,
          );
      if (!mounted) return;
      context.go(AppRouter.main);
    } catch (e) {
      appLog.e('[Register] 注册失败', e);
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = e.toString().replaceFirst(
            RegExp(r'^Exception:?\s*'),
            '',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
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
                        onChanged: (_) => setState(() => _errorText = null),
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
                  onChanged: (_) => setState(() => _errorText = null),
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
                        onChanged: (_) => setState(() => _errorText = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: FilledButton.tonal(
                        onPressed: (_countdown > 0 || _loading)
                            ? null
                            : _sendCode,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  onPressed: _loading ? null : _register,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
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
