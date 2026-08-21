import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 按住说话录音的完整生命周期：权限、临时文件、60s 上限、上滑取消、过短丢弃。
/// 状态变化通过 [ChangeNotifier] 通知输入区刷新录音浮层。
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController({this.onVoiceRecord});

  final void Function(int duration, String filePath)? onVoiceRecord;

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;
  String? _recordingPath;
  DateTime? _recordingStart;
  double _recordingStartDy = 0;

  bool _isRecording = false;
  bool _recordingCancel = false;

  bool get isRecording => _isRecording;
  bool get recordingCancel => _recordingCancel;

  Future<void> start(
    BuildContext context, [
    LongPressStartDetails? details,
  ]) async {
    _isRecording = true;
    _recordingCancel = false;
    _recordingStartDy = details?.globalPosition.dy ?? 0;
    notifyListeners();

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    _recordingStart = DateTime.now();

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _clearRecording();
        if (!context.mounted) return;
        _showMessage(context, '没有录音权限');
        return;
      }
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );
    } catch (_) {
      _clearRecording();
      if (!context.mounted) return;
      _showMessage(context, '录音启动失败');
      return;
    }

    _recordingTimer = Timer(const Duration(seconds: 60), () {
      stop(context);
    });
  }

  /// 录音手势移动：上滑超过 60px 进入取消态（业界"上滑取消"）
  void onMove(LongPressMoveUpdateDetails details) {
    final cancel = details.globalPosition.dy < _recordingStartDy - 60;
    if (cancel != _recordingCancel) {
      _recordingCancel = cancel;
      notifyListeners();
    }
  }

  Future<void> stop(
    BuildContext context, [
    LongPressEndDetails? details,
  ]) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (_isRecording) {
      _isRecording = false;
      notifyListeners();
    }

    if (_recordingPath == null || _recordingStart == null) return;

    // 横滑/上滑取消：先停止录音（否则麦克风会一直占用），再丢弃文件
    if (_recordingCancel) {
      final path = _recordingPath;
      _recordingPath = null;
      _recordingStart = null;
      try {
        await _recorder.stop();
      } catch (_) {
        // 停止失败也要继续清理文件
      }
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // 删除临时文件失败可忽略
        }
      }
      if (!context.mounted) return;
      _showMessage(
        context,
        '已取消录音',
        duration: const Duration(milliseconds: 800),
      );
      return;
    }

    final path = await _recorder.stop() ?? _recordingPath;
    final duration = DateTime.now().difference(_recordingStart!).inSeconds;

    _recordingPath = null;
    _recordingStart = null;

    if (duration < 1) {
      // 过短录音不发送，清理临时文件
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // 删除临时文件失败可忽略
        }
      }
      if (!context.mounted) return;
      _showMessage(context, '录音时间太短', duration: const Duration(seconds: 1));
      return;
    }

    if (path != null) {
      onVoiceRecord?.call(duration, path);
    }
  }

  void _clearRecording() {
    _recordingPath = null;
    _recordingStart = null;
    if (_isRecording) {
      _isRecording = false;
      notifyListeners();
    }
  }

  void _showMessage(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
