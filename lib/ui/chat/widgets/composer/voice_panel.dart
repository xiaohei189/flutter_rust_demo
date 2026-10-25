import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 语音面板的设计高度：输入区按它（与键盘高度取较大者）给面板占位。
const double kVoicePanelHeight = 300;

/// 语音输入面板（对齐飞书）：提示文案 + 大圆「按住说话」按钮。
///
/// 录音生命周期仍由 `VoiceRecorderController` 负责（权限、60s 上限、上滑取消、
/// 过短丢弃）；这里只做手势转发与状态呈现。
class VoicePanel extends StatelessWidget {
  const VoicePanel({
    super.key,
    required this.onRecordStart,
    this.onRecordMove,
    this.onRecordEnd,
    this.recording = false,
    this.cancel = false,
  });

  final void Function(LongPressStartDetails details) onRecordStart;
  final void Function(LongPressMoveUpdateDetails details)? onRecordMove;
  final void Function(LongPressEndDetails details)? onRecordEnd;

  /// 正在录音（按钮放大、提示变「松开 发送」）。
  final bool recording;

  /// 上滑到取消区（按钮变红、提示变「松开手指，取消发送」）。
  final bool cancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // 只有确实在录音时「上滑取消」态才有意义，避免残留标记把面板染红。
    final canceling = recording && cancel;
    final String hint;
    if (!recording) {
      hint = '按住 说话';
    } else if (canceling) {
      hint = '松开手指，取消发送';
    } else {
      hint = '松开 发送，上滑 取消';
    }

    return Container(
      height: kVoicePanelHeight,
      color: colors.attachmentBackground,
      alignment: Alignment.center,
      // 横屏/小窗口下输入区只分到 ~160dp，而语音面板的固定内容约 197dp，
      // 直接 Column 会 RenderFlex overflow；这里整块等比缩小，保持手势区域完整。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Text(
              hint,
              style: TextStyle(
                fontSize: 13,
                color: canceling ? colors.danger : colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              key: const ValueKey('voice_panel_record_button'),
              onLongPressStart: onRecordStart,
              onLongPressMoveUpdate: onRecordMove,
              onLongPressEnd: onRecordEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: recording ? 116 : 104,
                height: recording ? 116 : 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canceling ? colors.danger : colors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(
                        alpha: recording ? 0.28 : 0.16,
                      ),
                      blurRadius: recording ? 20 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.mic, size: 44, color: colors.onPrimary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '长按录音，上滑取消，最长 60 秒',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
