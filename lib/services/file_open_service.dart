import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class FileOpenService {
  static final FileOpenService instance = FileOpenService._internal();

  FileOpenService._internal();

  Future<bool> open({
    required String source,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final path = await _resolveLocalFile(source, fileName, onProgress);
    final mimeType = lookupMimeType(path);
    final result = await OpenFilex.open(
      path,
      type: mimeType ?? 'application/octet-stream',
    );
    return result.type == ResultType.done;
  }

  Future<String> _resolveLocalFile(
    String source,
    String fileName, [
    void Function(double progress)? onProgress,
  ]) async {
    if (!source.startsWith('http://') && !source.startsWith('https://')) {
      final local = File(source);
      if (local.existsSync()) return source;
      throw Exception('本地文件不存在: $source');
    }

    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final target = File('${dir.path}/$safeName');
    if (target.existsSync()) return target.path;

    final request = http.Request('GET', Uri.parse(source));
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('下载失败，HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0, 1));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return target.path;
  }
}
