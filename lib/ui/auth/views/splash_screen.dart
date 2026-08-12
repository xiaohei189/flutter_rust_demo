import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/app_paths.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// 启动页：有本地凭证则尝试自动登录并进入主页，否则进入登录页
class SplashScreen extends ConsumerStatefulWidget {
  final String wsUrl;
  final String apiBaseUrl;

  const SplashScreen({
    super.key,
    this.wsUrl = 'ws://localhost:10001',
    this.apiBaseUrl = 'http://localhost:10002',
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final ok = await ref
        .read(authViewModelProvider.notifier)
        .autoLogin(wsUrl: widget.wsUrl, apiBaseUrl: widget.apiBaseUrl);
    if (!mounted) return;

    context.go(ok ? AppPaths.main : AppPaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: colors.background,
          gradient: LinearGradient(
            colors: [colors.primary.withValues(alpha: 0.08), colors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ignore: prefer_const_constructors
              Icon(Icons.chat_bubble_outline, size: 80, color: colors.primary),
              const SizedBox(height: 16),
              // ignore: prefer_const_constructors
              Text(
                'Flutter 聊天',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              CircularProgressIndicator(color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
