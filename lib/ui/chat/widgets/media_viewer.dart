import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_image.dart';

bool _isRemote(String source) =>
    source.startsWith('http://') || source.startsWith('https://');

Future<void> openImagePreview(
  BuildContext context, {
  required String source,
  required String suggestedName,
}) async {
  await context.push<void>(
    '/media/image?source=${Uri.encodeQueryComponent(source)}'
    '&name=${Uri.encodeQueryComponent(suggestedName)}',
  );
}

Future<void> openVideoPreview(
  BuildContext context, {
  required String source,
}) async {
  if (source.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('视频地址为空，无法播放')));
    return;
  }
  await context.push<void>(
    '/media/video?source=${Uri.encodeQueryComponent(source)}',
  );
}

Future<void> saveMessageMedia(
  BuildContext context, {
  required String source,
  required String suggestedName,
}) async {
  if (source.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('文件地址为空，无法保存')));
    return;
  }

  try {
    final Uint8List bytes;
    if (_isRemote(source)) {
      final response = await http.get(Uri.parse(source));
      if (response.statusCode != 200) {
        throw Exception('下载失败，HTTP ${response.statusCode}');
      }
      bytes = response.bodyBytes;
    } else {
      final file = File(source);
      if (!file.existsSync()) {
        throw Exception('本地文件不存在: $source');
      }
      bytes = await file.readAsBytes();
    }

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: suggestedName,
      bytes: bytes,
    );
    if (savedPath != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已保存到 $savedPath')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }
}

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({
    super.key,
    required this.source,
    required this.suggestedName,
  });

  final String source;
  final String suggestedName;

  @override
  Widget build(BuildContext context) {
    final image = AppImage(
      source: source,
      fit: BoxFit.contain,
      errorWidget: Icon(
        Icons.broken_image,
        size: 96,
        color: context.appColors.onPrimary.withValues(alpha: 0.54),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: context.appColors.onPrimary,
        title: const Text('图片预览'),
        actions: [
          IconButton(
            tooltip: '保存图片',
            icon: const Icon(Icons.save_alt),
            onPressed: () => saveMessageMedia(
              context,
              source: source,
              suggestedName: suggestedName,
            ),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5,
        child: Center(child: image),
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  const VideoPreviewScreen({super.key, required this.source});

  final String source;

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = _isRemote(widget.source)
          ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
          : VideoPlayerController.file(File(widget.source));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '视频播放失败: $e';
          _initializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: context.appColors.onPrimary,
        title: const Text('视频播放'),
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return CircularProgressIndicator(
        color: context.appColors.onPrimary.withValues(alpha: 0.7),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.appColors.onPrimary.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final controller = _controller!;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: context.appColors.primary,
                bufferedColor: context.appColors.onPrimary.withValues(
                  alpha: 0.38,
                ),
                backgroundColor: context.appColors.surface.withValues(
                  alpha: 0.24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
