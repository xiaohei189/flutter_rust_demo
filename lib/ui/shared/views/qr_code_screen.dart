import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../router/app_router.dart';
import '../../../ui/core/theme/app_theme.dart';

/// 通用二维码展示页：我的二维码 / 群二维码。
class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({
    super.key,
    required this.title,
    required this.data,
    this.subtitle,
  });

  final String title;
  final String data;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: colors.cardShadow,
                ),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 240,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                data,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
