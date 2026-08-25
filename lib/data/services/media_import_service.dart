import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// 媒体导入服务：包装文件选择、定位、视频时长与缩略图等平台插件。
class MediaImportService {
  const MediaImportService();

  /// 选择单个文件，返回本地路径；用户取消时返回 null。
  Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  /// 保存文件到用户指定位置，返回保存路径；用户取消时返回 null。
  Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: '保存文件',
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// 获取当前位置；定位不可用或失败时返回 null。
  Future<({double latitude, double longitude})?> currentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// 读取本地视频时长（秒）；解析失败返回 0。
  Future<int> videoDuration(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      await controller.dispose();
      return duration;
    } catch (_) {
      return 0;
    }
  }

  /// 下载文件内容：远程 URL 走 HTTP，本地路径直接读取。
  Future<Uint8List> downloadBytes(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final response = await http.get(Uri.parse(source));
      if (response.statusCode != 200) {
        throw Exception('下载失败，HTTP ${response.statusCode}');
      }
      return response.bodyBytes;
    }
    final file = File(source);
    if (!file.existsSync()) {
      throw Exception('本地文件不存在: $source');
    }
    return file.readAsBytes();
  }

  /// 生成视频缩略图路径；失败返回空字符串。
  Future<String> videoThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumb = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath:
            '${tempDir.path}/video_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720,
        quality: 80,
      );
      return thumb.path;
    } catch (_) {
      return '';
    }
  }
}
