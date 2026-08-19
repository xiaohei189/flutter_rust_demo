import 'package:flutter/material.dart';

import '../../../../data/services/audio_player_service.dart';
import '../../../../domain/extensions/message_ext.dart';
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';

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
        borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 40, color: colors.textSecondary),
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
              borderRadius: BorderRadius.circular(8),
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
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
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
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
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
  });

  final ChatMessage message;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (message.soundSource.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('语音地址为空，无法播放')));
          return;
        }
        audioPlayerService.play(message.soundSource);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 24,
            color: isFromMe
                ? context.appColors.onPrimary
                : context.appColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            message.audioDurationString,
            style: TextStyle(
              color: isFromMe
                  ? context.appColors.onPrimary
                  : context.appColors.bubbleOtherText,
              fontSize: 16,
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
