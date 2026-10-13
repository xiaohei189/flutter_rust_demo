import 'package:flutter/material.dart';

import '../../../mappers/message_display.dart';
import '../../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../../data/services/audio_player_service.dart'
    show AudioPlaybackState;

class UploadProgress extends StatelessWidget {
  const UploadProgress({
    super.key,
    required this.isFromMe,
    required this.progress,
    required this.child,
  });

  final bool isFromMe;
  final int? progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isFromMe || progress == null || progress! >= 100) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        SizedBox(
          width: 150,
          child: LinearProgressIndicator(
            value: progress! / 100,
            minHeight: 3,
            backgroundColor: context.appColors.onPrimary.withValues(
              alpha: 0.15,
            ),
          ),
        ),
      ],
    );
  }
}

class ImageMessageContent extends StatelessWidget {
  const ImageMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
    this.uploadProgress,
  });

  final ChatMessage message;
  final bool isFromMe;
  final int? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final source = message.displayImageSource;
    if (source.isEmpty) {
      return const _ImageMessagePlaceholder(text: '图片地址为空');
    }
    return UploadProgress(
      isFromMe: isFromMe,
      progress: uploadProgress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: AppImage(
          source: source,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
          cacheWidth: 300,
          errorWidget: const _ImageMessagePlaceholder(text: '图片加载失败'),
        ),
      ),
    );
  }
}

class _ImageMessagePlaceholder extends StatelessWidget {
  const _ImageMessagePlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: colors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class VideoMessageContent extends StatelessWidget {
  const VideoMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
    this.uploadProgress,
  });

  final ChatMessage message;
  final bool isFromMe;
  final int? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final snap = message.videoSnapshotPath;
    return UploadProgress(
      isFromMe: isFromMe,
      progress: uploadProgress,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (snap.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: AppImage(
                source: snap,
                width: 150,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 300,
              ),
            )
          else
            Container(
              width: 150,
              height: 120,
              decoration: BoxDecoration(
                // 视频封面未就绪时的占位底：取媒体遮罩 token 的浅色档
                color: context.appColors.mediaScrim.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          Icon(
            Icons.play_circle_fill,
            size: 40,
            color: context.appColors.onPrimary,
          ),
          if (message.videoDurationString != '0:00')
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.appColors.mediaScrim,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  message.videoDurationString,
                  style: TextStyle(
                    color: context.appColors.onPrimary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AudioMessageContent extends StatelessWidget {
  const AudioMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
    this.onPlay,
    this.playback,
  });

  final ChatMessage message;
  final bool isFromMe;

  /// 播放语音回调；为空时（预览/测试场景）点击不触发播放。
  final void Function(String source)? onPlay;

  /// 当前播放状态；播放中的是这条语音时展示停止图标与进度条。
  final AudioPlaybackState? playback;

  @override
  Widget build(BuildContext context) {
    final isPlayingThis = playback?.isPlayingSource(message.soundSource) ?? false;
    final foreground = isFromMe
        ? context.appColors.onPrimary
        : context.appColors.bubbleOtherText;
    return GestureDetector(
      onTap: () {
        if (message.soundSource.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('语音地址为空，无法播放')));
          return;
        }
        onPlay?.call(message.soundSource);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 圆形播放/停止按钮（对齐飞书：对方语音为蓝底白图标，自己语音为半透明白底）
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFromMe
                  ? context.appColors.onPrimary.withValues(alpha: 0.22)
                  : context.appColors.primary,
            ),
            child: Icon(
              isPlayingThis ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: context.appColors.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          AudioProgressTrack(
            progress: isPlayingThis ? (playback?.progress ?? 0) : 0,
            trackColor: foreground.withValues(alpha: 0.25),
            dotColor: isFromMe
                ? context.appColors.onPrimary
                : context.appColors.surface,
          ),
          const SizedBox(width: 10),
          Text(
            message.audioDurationString,
            style: TextStyle(color: foreground, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// 语音播放进度轨道：浅色底线 + 随进度移动的圆点（对齐飞书气泡）。
///
/// 空闲（未播放）时圆点停在最左端，播放中随进度右移；轨道宽度固定，
/// 因此开始/结束播放不会改变气泡高度与宽度。
class AudioProgressTrack extends StatelessWidget {
  const AudioProgressTrack({
    super.key,
    required this.progress,
    required this.trackColor,
    required this.dotColor,
    this.width = 72,
  });

  final double progress;
  final Color trackColor;
  final Color dotColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: 8,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(width: width, height: 2, color: trackColor),
          // 圆点位置 = 进度：用 Align(-1 ~ 1) 把 0~1 映射到轨道两端
          Align(
            alignment: Alignment(value * 2 - 1, 0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FileMessageContent extends StatelessWidget {
  const FileMessageContent({
    super.key,
    required this.message,
    required this.isFromMe,
    this.uploadProgress,
  });

  final ChatMessage message;
  final bool isFromMe;
  final int? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final ext = message.fileExtension.toLowerCase();
    final iconData = switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' => Icons.table_chart,
      'ppt' || 'pptx' => Icons.slideshow,
      'zip' || 'rar' => Icons.folder_zip,
      _ => Icons.insert_drive_file,
    };
    final iconColor = isFromMe
        ? context.appColors.onPrimary.withValues(alpha: 0.7)
        : context.appColors.primary;

    return UploadProgress(
      isFromMe: isFromMe,
      progress: uploadProgress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 36, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.fileName.isNotEmpty ? message.fileName : '未知文件',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFromMe
                        ? context.appColors.onPrimary
                        : context.appColors.bubbleOtherText,
                    fontSize: 14,
                  ),
                ),
                if (message.fileSizeString.isNotEmpty)
                  Text(
                    message.fileSizeString,
                    style: TextStyle(
                      color: isFromMe
                          ? context.appColors.onPrimary.withValues(alpha: 0.7)
                          : context.appColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
