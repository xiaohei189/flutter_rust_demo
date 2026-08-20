import '../../../../domain/models/chat_message.dart' show ChatMessage;
import 'message_parsed.dart' show parsedContentOf;

/// 消息媒体/内容类型的展示 getter。
extension ChatMessageMediaExt on ChatMessage {
  // ---- 图片 ----
  String get imagePath {
    final json = parsedContentOf(this);
    final src = json['sourcePicture'];
    if (src is Map) return src['url'] as String? ?? '';
    return '';
  }

  String get snapshotPath {
    final json = parsedContentOf(this);
    final snap = json['snapshotPicture'];
    if (snap is Map) return snap['url'] as String? ?? '';
    return '';
  }

  String get bigPicturePath {
    final json = parsedContentOf(this);
    final big = json['bigPicture'];
    if (big is Map) return big['url'] as String? ?? '';
    return '';
  }

  String get displayImageSource {
    if (imagePath.isNotEmpty) return imagePath;
    if (snapshotPath.isNotEmpty) return snapshotPath;
    return bigPicturePath;
  }

  int get imageWidth {
    final src = parsedContentOf(this)['sourcePicture'];
    if (src is Map) return src['width'] as int? ?? 0;
    return 0;
  }

  int get imageHeight {
    final src = parsedContentOf(this)['sourcePicture'];
    if (src is Map) return src['height'] as int? ?? 0;
    return 0;
  }

  int get imageOrFileSize => parsedContentOf(this)['size'] as int? ?? 0;

  // ---- 视频 ----
  String get videoPath => parsedContentOf(this)['videoPath'] as String? ?? '';
  String get videoSource {
    if (videoPath.isNotEmpty) return videoPath;
    return parsedContentOf(this)['videoUrl'] as String? ?? '';
  }

  String get videoSnapshotPath => parsedContentOf(this)['snapshotPath'] as String? ?? '';
  int get videoDuration => parsedContentOf(this)['duration'] as int? ?? 0;
  int get videoSize => parsedContentOf(this)['size'] as int? ?? 0;

  // ---- 语音 ----
  String get soundPath => parsedContentOf(this)['soundPath'] as String? ?? '';
  String get soundSource {
    if (soundPath.isNotEmpty) return soundPath;
    return parsedContentOf(this)['sourceUrl'] as String? ?? '';
  }

  int get audioDuration => parsedContentOf(this)['duration'] as int? ?? 0;
  int get audioDataSize => parsedContentOf(this)['dataSize'] as int? ?? 0;

  // ---- 文件 ----
  String get filePath => parsedContentOf(this)['filePath'] as String? ?? '';
  String get fileSource {
    if (filePath.isNotEmpty) return filePath;
    return parsedContentOf(this)['sourceUrl'] as String? ??
        parsedContentOf(this)['url'] as String? ??
        '';
  }

  String get fileName => parsedContentOf(this)['fileName'] as String? ?? '';
  int get fileSize => parsedContentOf(this)['fileSize'] as int? ?? 0;
  String get fileType => parsedContentOf(this)['fileType'] as String? ?? '';

  String get fileExtension {
    final name = fileName;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex >= 0 ? name.substring(dotIndex + 1) : '';
  }

  // ---- 位置 ----
  String get locationName => parsedContentOf(this)['name'] as String? ?? '';
  String get locationDesc => parsedContentOf(this)['desc'] as String? ?? '';
  double get latitude => (parsedContentOf(this)['latitude'] as num?)?.toDouble() ?? 0.0;
  double get longitude => (parsedContentOf(this)['longitude'] as num?)?.toDouble() ?? 0.0;

  // ---- 名片 ----
  String get cardUserId => parsedContentOf(this)['userID'] as String? ?? '';
  String get cardNickname => parsedContentOf(this)['nickname'] as String? ?? '';
  String get cardFaceUrl => parsedContentOf(this)['faceUrl'] as String? ?? '';

  // ---- 合并转发 ----
  String get mergeTitle => parsedContentOf(this)['title'] as String? ?? '';
  int get mergeMessageCount {
    final list = parsedContentOf(this)['multiMessage'];
    if (list is List) return list.length;
    return 0;
  }

  List<String> get mergeSenderNicknames {
    final list = parsedContentOf(this)['abstractList'];
    if (list is List) return list.cast<String>();
    return [];
  }

  // ---- 引用 ----
  String get quoteText => parsedContentOf(this)['text'] as String? ?? '';
  String get quoteReplyMessageId => parsedContentOf(this)['replyMessageId'] as String? ?? '';
  String get quoteSenderNickname => parsedContentOf(this)['senderNickname'] as String? ?? '';
  int get quoteReplyContentType => parsedContentOf(this)['replyMessageContentType'] as int? ?? 0;
  String get quoteReplyContent => parsedContentOf(this)['replyMessageContent'] as String? ?? '';

  // ---- @ ----
  List<String> get atUserIds {
    final users = parsedContentOf(this)['atUsers'];
    if (users is List) {
      return users
          .whereType<Map<String, dynamic>>()
          .map((u) => u['atUserID'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<String> get atNicknames {
    final users = parsedContentOf(this)['atUsers'];
    if (users is List) {
      return users
          .whereType<Map<String, dynamic>>()
          .map((u) => u['nickname'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  // ---- 表情 ----
  int get faceIndex => parsedContentOf(this)['index'] as int? ?? 0;

  // ---- 自定义 ----
  String get customData => parsedContentOf(this)['data'] as String? ?? '';
  String get customExtension => parsedContentOf(this)['extension'] as String? ?? '';

  // ---- 时长/大小格式化 ----
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String get audioDurationString => _formatDuration(audioDuration);
  String get videoDurationString => _formatDuration(videoDuration);

  String get fileSizeString {
    final size = fileSize > 0 ? fileSize : (videoSize > 0 ? videoSize : imageOrFileSize);
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}