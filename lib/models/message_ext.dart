import 'dart:convert';

import '../src/rust/domain/model/message.dart' show MessageInfo, ReceivedMessage;
import 'message.dart' show MessageType, MessageSendStatus, messageTypeFromContentType;

/// 给 Rust 生成的 MessageInfo 添加 UI 便利方法
extension MessageInfoExt on MessageInfo {
  /// 消息类型枚举
  MessageType get messageType => messageTypeFromContentType(contentType);

  /// 解析后的 content JSON
  Map<String, dynamic> get parsedContent {
    if (content.isEmpty || !content.startsWith('{')) return {};
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 显示用的文本内容
  String get displayText {
    final json = parsedContent;
    return switch (messageType) {
      MessageType.text => json['content'] as String? ?? content,
      MessageType.advancedText => json['content'] as String? ?? '',
      MessageType.markdown => json['content'] as String? ?? '',
      MessageType.quote => json['text'] as String? ?? '',
      MessageType.at => json['text'] as String? ?? '',
      MessageType.merge => '[聊天记录] ${json['messageCount'] as int? ?? 0}条消息',
      _ => content,
    };
  }

  /// 发送时间 DateTime
  DateTime get sendDateTime {
    final t = sendTime.toInt();
    return t > 0 ? DateTime.fromMillisecondsSinceEpoch(t) : DateTime.fromMillisecondsSinceEpoch(createTime.toInt());
  }

  /// 消息发送状态（仅自己发的消息有效）
  MessageSendStatus? get messageSendStatus => MessageSendStatus.fromValue(status);

  // ---- 图片 ----
  String get imagePath {
    final json = parsedContent;
    final src = json['sourcePicture'];
    if (src is Map) return src['url'] as String? ?? '';
    return '';
  }

  String get snapshotPath {
    final json = parsedContent;
    final snap = json['snapshotPicture'];
    if (snap is Map) return snap['url'] as String? ?? '';
    return '';
  }

  String get bigPicturePath {
    final json = parsedContent;
    final big = json['bigPicture'];
    if (big is Map) return big['url'] as String? ?? '';
    return '';
  }

  /// 图片最佳显示路径（优先 source → snapshot → big）
  String get displayImageSource {
    if (imagePath.isNotEmpty) return imagePath;
    if (snapshotPath.isNotEmpty) return snapshotPath;
    return bigPicturePath;
  }

  int get imageWidth {
    final json = parsedContent;
    final src = json['sourcePicture'];
    if (src is Map) return src['width'] as int? ?? 0;
    return 0;
  }

  int get imageHeight {
    final json = parsedContent;
    final src = json['sourcePicture'];
    if (src is Map) return src['height'] as int? ?? 0;
    return 0;
  }

  int get imageOrFileSize {
    final json = parsedContent;
    return json['size'] as int? ?? 0;
  }

  // ---- 视频 ----
  String get videoPath => parsedContent['videoPath'] as String? ?? '';
  String get videoSnapshotPath => parsedContent['snapshotPath'] as String? ?? '';
  int get videoDuration => parsedContent['duration'] as int? ?? 0;
  int get videoSize => parsedContent['size'] as int? ?? 0;

  // ---- 语音 ----
  String get soundPath => parsedContent['soundPath'] as String? ?? '';
  int get audioDuration => parsedContent['duration'] as int? ?? 0;
  int get audioDataSize => parsedContent['dataSize'] as int? ?? 0;

  // ---- 文件 ----
  String get filePath => parsedContent['filePath'] as String? ?? '';
  String get fileName => parsedContent['fileName'] as String? ?? '';
  int get fileSize => parsedContent['fileSize'] as int? ?? 0;
  String get fileType => parsedContent['fileType'] as String? ?? '';

  /// 文件扩展名
  String get fileExtension {
    final name = fileName;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex >= 0 ? name.substring(dotIndex + 1) : '';
  }

  // ---- 位置 ----
  String get locationName => parsedContent['name'] as String? ?? '';
  String get locationDesc => parsedContent['desc'] as String? ?? '';
  double get latitude => (parsedContent['latitude'] as num?)?.toDouble() ?? 0.0;
  double get longitude => (parsedContent['longitude'] as num?)?.toDouble() ?? 0.0;

  // ---- 名片 ----
  String get cardUserId => parsedContent['userID'] as String? ?? '';
  String get cardNickname => parsedContent['nickname'] as String? ?? '';
  String get cardFaceUrl => parsedContent['faceUrl'] as String? ?? '';

  // ---- 合并转发 ----
  String get mergeTitle => parsedContent['title'] as String? ?? '';
  int get mergeMessageCount => parsedContent['messageCount'] as int? ?? 0;
  List<String> get mergeSenderNicknames {
    final list = parsedContent['senderNicknameList'];
    if (list is List) return list.cast<String>();
    return [];
  }

  // ---- 引用 ----
  String get quoteText => parsedContent['text'] as String? ?? '';
  String get quoteReplyMessageId => parsedContent['replyMessageId'] as String? ?? '';
  String get quoteSenderNickname => parsedContent['senderNickname'] as String? ?? '';
  int get quoteReplyContentType => parsedContent['replyMessageContentType'] as int? ?? 0;
  String get quoteReplyContent => parsedContent['replyMessageContent'] as String? ?? '';

  // ---- @ ----
  List<String> get atUserIds {
    final users = parsedContent['atUsers'];
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
    final users = parsedContent['atUsers'];
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
  int get faceIndex => parsedContent['index'] as int? ?? 0;

  // ---- 自定义 ----
  String get customData => parsedContent['data'] as String? ?? '';
  String get customExtension => parsedContent['extension'] as String? ?? '';

  // ---- 时长格式化 ----
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String get audioDurationString => _formatDuration(audioDuration);
  String get videoDurationString => _formatDuration(videoDuration);

  // ---- 文件大小格式化 ----
  String get fileSizeString {
    final size = fileSize > 0 ? fileSize : (videoSize > 0 ? videoSize : imageOrFileSize);
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// ReceivedMessage → MessageInfo 转换
extension ReceivedMessageExt on ReceivedMessage {
  MessageInfo toMessageInfo() => MessageInfo(
        clientMsgId: clientMsgId,
        serverMsgId: serverMsgId,
        sendId: sendId,
        recvId: recvId,
        groupId: groupId,
        senderPlatformId: senderPlatformId,
        senderNickname: senderNickName,
        senderFaceUrl: senderFaceUrl,
        sessionType: sessionType,
        msgFrom: msgFrom,
        contentType: contentType,
        content: content,
        seq: seq,
        sendTime: sendTime,
        createTime: createTime,
        status: 0, // 收到的消息无需显示发送状态
        isRead: false,
        attachedInfo: '',
        ex: '',
      );
}

/// 从 messageSent 事件构造 MessageInfo
MessageInfo messageSentToInfo({
  required String clientMsgId,
  required String serverMsgId,
  required int sendTimeMs,
  required int status,
  required String conversationId,
  required String sendId,
  required String recvId,
  required String groupId,
  required int sessionType,
  required int contentType,
  required String content,
  required String senderNickname,
  required String senderFaceUrl,
}) =>
    MessageInfo(
      clientMsgId: clientMsgId,
      serverMsgId: serverMsgId,
      sendId: sendId,
      recvId: recvId,
      groupId: groupId,
      senderPlatformId: 0,
      senderNickname: senderNickname,
      senderFaceUrl: senderFaceUrl,
      sessionType: sessionType,
      msgFrom: 0,
      contentType: contentType,
      content: content,
      seq: 0,
      sendTime: sendTimeMs,
      createTime: sendTimeMs,
      status: status,
      isRead: false,
      attachedInfo: '',
      ex: '',
    );
