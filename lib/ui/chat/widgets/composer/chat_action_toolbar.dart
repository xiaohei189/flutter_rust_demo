import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 输入区底部完整工具栏（主输入框与展开编辑抽屉共用）。
///
/// 一行内从左到右：表情 / @ / 语音 / 图片 / Aa(Markdown) / 更多，
/// 图标区可横向滚动防溢出；最右固定「发送」文字按钮（无文字时置灰）。
class ChatActionToolbar extends StatelessWidget {
  /// 表情/更多面板是否处于展开态（决定实心/空心图标）
  final bool emojiActive;
  final bool moreActive;

  /// 当前是否 Markdown 模式（Aa 图标高亮）
  final bool markdownActive;
  final String markdownTooltip;

  /// 输入框是否有文字（驱动发送按钮可用态）
  final ValueListenable<bool> hasText;

  // —— 各图标点击 ——
  final VoidCallback onEmoji;
  final VoidCallback onAt;
  final VoidCallback onImage;
  final VoidCallback onFormat;
  final VoidCallback onMore;
  final VoidCallback onSend;

  /// 相册是否可用（未提供 onImagePick 时置灰）
  final bool imageEnabled;

  /// 语音长按录音手势（可选；未提供时退化为普通点击）
  final void Function(LongPressStartDetails)? onVoiceLongPressStart;
  final void Function(LongPressMoveUpdateDetails)? onVoiceLongPressMoveUpdate;
  final void Function(LongPressEndDetails)? onVoiceLongPressEnd;
  final VoidCallback? onVoiceTap;

  const ChatActionToolbar({
    super.key,
    required this.emojiActive,
    required this.moreActive,
    required this.markdownActive,
    required this.markdownTooltip,
    required this.hasText,
    required this.onEmoji,
    required this.onAt,
    required this.onImage,
    required this.onFormat,
    required this.onMore,
    required this.onSend,
    this.imageEnabled = true,
    this.onVoiceLongPressStart,
    this.onVoiceLongPressMoveUpdate,
    this.onVoiceLongPressEnd,
    this.onVoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // 😊 表情
                  _ToolbarIcon(
                    icon: emojiActive ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    tooltip: emojiActive ? '键盘' : '表情',
                    onTap: onEmoji,
                  ),
                  // @ 提及
                  _ToolbarIcon(
                    icon: Icons.alternate_email,
                    tooltip: '@ 提及',
                    onTap: onAt,
                  ),
                  // 🎤 语音（长按录音，上滑取消）
                  if (onVoiceLongPressStart != null)
                    _VoiceToolbarIcon(
                      onLongPressStart: onVoiceLongPressStart!,
                      onLongPressMoveUpdate: onVoiceLongPressMoveUpdate,
                      onLongPressEnd: onVoiceLongPressEnd,
                      onTap: onVoiceTap,
                    )
                  else
                    _ToolbarIcon(
                      icon: Icons.mic_none,
                      tooltip: '语音',
                      onTap: onVoiceTap ?? () {},
                    ),
                  // 🖼️ 相册
                  _ToolbarIcon(
                    icon: Icons.photo_library_outlined,
                    tooltip: '相册',
                    onTap: onImage,
                    enabled: imageEnabled,
                  ),
                  // Aa 格式
                  _ToolbarIcon(
                    textLabel: 'Aa',
                    tooltip: markdownTooltip,
                    active: markdownActive,
                    onTap: onFormat,
                  ),
                  // ➕ 更多
                  _ToolbarIcon(
                    icon: moreActive ? Icons.add_circle : Icons.add_circle_outline,
                    tooltip: '更多',
                    onTap: onMore,
                  ),
                ],
              ),
            ),
          ),
          // ➡️ 发送（始终显示，最右；无文字时置灰）
          ValueListenableBuilder<bool>(
            valueListenable: hasText,
            builder: (_, hasTextValue, __) {
              return SendButton(enabled: hasTextValue, onSend: onSend);
            },
          ),
        ],
      ),
    );
  }
}

/// 普通工具栏图标按钮（飞书风格：24px 线性图标，等宽）
class _ToolbarIcon extends StatelessWidget {
  final IconData? icon;
  final String? textLabel;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  const _ToolbarIcon({
    this.icon,
    this.textLabel,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  }) : assert(icon != null || textLabel != null);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            icon: textLabel != null
                ? Text(
                    textLabel!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: enabled
                          ? (active
                                ? colors.primary
                                : colors.textPrimary.withValues(alpha: 0.7))
                          : colors.textSecondary.withValues(alpha: 0.3),
                    ),
                  )
                : Icon(
                    icon!,
                    size: 24,
                    color: enabled
                        ? (active
                              ? colors.primary
                              : colors.textPrimary.withValues(alpha: 0.7))
                        : colors.textSecondary.withValues(alpha: 0.3),
                  ),
            onPressed: enabled ? onTap : null,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

/// 语音图标（长按录音手势）
class _VoiceToolbarIcon extends StatelessWidget {
  final void Function(LongPressStartDetails) onLongPressStart;
  final void Function(LongPressMoveUpdateDetails)? onLongPressMoveUpdate;
  final void Function(LongPressEndDetails)? onLongPressEnd;
  final VoidCallback? onTap;

  const _VoiceToolbarIcon({
    required this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final btn = Tooltip(
      message: '语音（长按录音，上滑取消）',
      child: Semantics(
        label: '语音（长按录音，上滑取消）',
        button: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            icon: Icon(
              Icons.mic_none,
              size: 24,
              color: colors.textPrimary.withValues(alpha: 0.7),
            ),
            onPressed: null,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd,
      child: btn,
    );
  }
}

/// 发送文字按钮：始终显示，无文字时置灰不可点
class SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSend;

  const SendButton({super.key, required this.enabled, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = enabled ? colors.primary : colors.textSecondary.withValues(alpha: 0.22);
    return Semantics(
      button: true,
      label: '发送',
      child: InkWell(
        onTap: enabled ? onSend : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '发送',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
