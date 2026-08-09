import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

bool _isRemote(String source) =>
    source.startsWith('http://') || source.startsWith('https://');

Future<void> openImagePreview(
  BuildContext context, {
  required String source,
  required String suggestedName,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _ImagePreviewScreen(source: source, suggestedName: suggestedName),
    ),
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
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _VideoPreviewScreen(source: source),
    ),
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

class _ImagePreviewScreen extends StatelessWidget {
  const _ImagePreviewScreen({
    required this.source,
    required this.suggestedName,
  });

  final String source;
  final String suggestedName;

  @override
  Widget build(BuildContext context) {
    final image = _isRemote(source)
        ? Image.network(
            source,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image, size: 96, color: Colors.white54),
          )
        : Image.file(
            File(source),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image, size: 96, color: Colors.white54),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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

class _VideoPreviewScreen extends StatefulWidget {
  const _VideoPreviewScreen({required this.source});

  final String source;

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
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
        foregroundColor: Colors.white,
        title: const Text('视频播放'),
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const CircularProgressIndicator(color: Colors.white70);
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
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
              colors: const VideoProgressColors(
                playedColor: AppTheme.primaryColor,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
