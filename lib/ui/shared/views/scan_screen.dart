import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// 扫一扫（参考飞书）：全屏取景 + 四角取景框 + 扫描线，底部「相册 / 手电筒」。
///
/// 识别成功时 `pop` 出扫到的原始字符串（相册选图识别走同一条出口），
/// 由调用方决定怎么用；没识别到就留在页面上继续扫。
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  /// 已经拿到结果就不再重复 pop（相机回调会连续触发）。
  bool _handled = false;

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _finish(String raw) {
    if (_handled || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  static String? _firstRawValue(BarcodeCapture? capture) {
    if (capture == null) return null;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return null;
  }

  /// 从相册选一张二维码图片做离线识别。
  Future<void> _pickFromAlbum() async {
    if (_handled) return;
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file == null || !mounted) return;

    String? raw;
    try {
      raw = _firstRawValue(await _controller.analyzeImage(file.path));
    } catch (_) {
      raw = null;
    }
    if (!mounted || _handled) return;
    if (raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有识别到二维码，换一张再试试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _finish(raw);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      // 部分设备/模拟器没有闪光灯：按钮已经置灰，这里静默兜底
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.mediaBackground,
      // 取景框按整屏算坐标，所以不用 AppBar，标题和按钮自己叠在预览上
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final side = math.min(size.width * 0.68, 260.0);
              final frame = Rect.fromCenter(
                center: Offset(size.width / 2, size.height * 0.38),
                width: side,
                height: side,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    scanWindow: frame,
                    onDetect: (capture) {
                      final raw = _firstRawValue(capture);
                      if (raw != null) _finish(raw);
                    },
                    errorBuilder: (context, error) =>
                        _buildCameraError(context, error),
                  ),
                  AnimatedBuilder(
                    animation: _scanLine,
                    builder: (context, _) => CustomPaint(
                      painter: _ScanFramePainter(
                        frame: frame,
                        scrim: colors.mediaScrim,
                        accent: colors.onPrimary,
                        progress: _scanLine.value,
                      ),
                    ),
                  ),
                  Positioned(
                    top: frame.bottom + 20,
                    left: 32,
                    right: 32,
                    child: Text(
                      '将二维码放入框内，即可自动扫描',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          _buildTopBar(context),
          _buildBottomActions(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = context.appColors;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('scan_close_button'),
                icon: const Icon(Icons.close, size: 24),
                color: colors.onPrimary,
                tooltip: '关闭',
                onPressed: () => AppRouter.goBack(context),
              ),
              const Spacer(),
              Text(
                '扫一扫',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimary,
                ),
              ),
              const Spacer(),
              // 与左侧关闭按钮等宽，让标题真正居中
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final colors = context.appColors;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScanActionButton(
                key: const ValueKey('scan_album_button'),
                icon: Icons.photo_library_outlined,
                label: '相册',
                onTap: _pickFromAlbum,
              ),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, _) {
                  final torchOn = state.torchState == TorchState.on;
                  final available = state.torchState != TorchState.unavailable;
                  return _ScanActionButton(
                    key: const ValueKey('scan_torch_button'),
                    icon: torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                    label: torchOn ? '关闭手电筒' : '手电筒',
                    color: available ? colors.onPrimary : colors.textSecondary,
                    onTap: available ? _toggleTorch : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 相机不可用（模拟器无摄像头 / 权限被拒）时的兜底：给出原因和相册出口。
  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final colors = context.appColors;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: colors.mediaBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 40,
                color: colors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                denied ? '没有相机权限，请在系统设置里允许后再试' : '摄像头不可用，可以从相册选一张二维码',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSmall,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部动作入口（飞书：图标 + 文案，竖排）。
class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tint = color ?? colors.onPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: tint),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: AppTheme.fontSizeCaption, color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 取景框：框外压暗 + 四角白框 + 上下往复的扫描线。
class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({
    required this.frame,
    required this.scrim,
    required this.accent,
    required this.progress,
  });

  final Rect frame;
  final Color scrim;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()..color = scrim;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, frame.top), scrimPaint);
    canvas.drawRect(
      Rect.fromLTRB(0, frame.bottom, size.width, size.height),
      scrimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, frame.top, frame.left, frame.bottom),
      scrimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(frame.right, frame.top, size.width, frame.bottom),
      scrimPaint,
    );

    final bracket = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arm = frame.width * 0.16;
    canvas.drawPath(
      Path()
        ..moveTo(frame.left, frame.top + arm)
        ..lineTo(frame.left, frame.top)
        ..lineTo(frame.left + arm, frame.top),
      bracket,
    );
    canvas.drawPath(
      Path()
        ..moveTo(frame.right - arm, frame.top)
        ..lineTo(frame.right, frame.top)
        ..lineTo(frame.right, frame.top + arm),
      bracket,
    );
    canvas.drawPath(
      Path()
        ..moveTo(frame.right, frame.bottom - arm)
        ..lineTo(frame.right, frame.bottom)
        ..lineTo(frame.right - arm, frame.bottom),
      bracket,
    );
    canvas.drawPath(
      Path()
        ..moveTo(frame.left + arm, frame.bottom)
        ..lineTo(frame.left, frame.bottom)
        ..lineTo(frame.left, frame.bottom - arm),
      bracket,
    );

    // 扫描线：上下往复 + 两端渐隐，避免生硬的横杠
    final travel = frame.height - 24;
    final offset = progress <= 0.5 ? progress * 2 : (1 - progress) * 2;
    final y = frame.top + 12 + travel * offset;
    final lineRect = Rect.fromLTRB(
      frame.left + 6,
      y - 1,
      frame.right - 6,
      y + 1,
    );
    canvas.drawRect(
      lineRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0),
            accent,
            accent.withValues(alpha: 0),
          ],
        ).createShader(lineRect),
    );
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.frame != frame ||
        oldDelegate.scrim != scrim ||
        oldDelegate.accent != accent;
  }
}
