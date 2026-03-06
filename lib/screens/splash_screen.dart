import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';
import 'main_screen.dart';
import '../utils/app_logger.dart';
import '../utils/login_storage.dart';

/// 启动页：有本地凭证则尝试自动登录并进入主页，否则进入登录页
class SplashScreen extends StatefulWidget {
  final String wsUrl;
  final String apiBaseUrl;

  const SplashScreen({
    super.key,
    this.wsUrl = 'ws://localhost:10001',
    this.apiBaseUrl = 'http://localhost:10002',
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final credentials = await LoginStorage.loadCredentials();
    if (credentials != null) {
      try {
        await messageService.initialize(
          wsUrl: widget.wsUrl,
          apiBaseUrl: widget.apiBaseUrl,
          userId: credentials.userId,
          imToken: credentials.imToken,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
        return;
      } catch (e) {
        appLog.w('自动登录失败，跳转登录页: $e');
        await LoginStorage.clearCredentials();
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(wsUrl: widget.wsUrl, apiBaseUrl: widget.apiBaseUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.08),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Flutter 聊天',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
