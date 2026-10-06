import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.mediaBackground,
      appBar: AppBar(
        title: const Text('扫一扫'),
        backgroundColor: context.appColors.mediaBackground,
        foregroundColor: context.appColors.onPrimary,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final raw = capture.barcodes
              .map((b) => b.rawValue ?? '')
              .where((v) => v.isNotEmpty)
              .firstOrNull;
          if (raw == null) return;
          _handled = true;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}

