import 'dart:convert';

import '../../generated/rust/model/local.dart' show LocalChatLog;
import '../models/chat_message.dart' show ChatMessage;
import '../models/message.dart'
    show MessageType, MessageSendStatus, messageTypeFromContentType;

/// 给 Rust 生成的 MessageInfo 添加 UI 便利方法
extension ChatMessageExt on ChatMessage {
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
      MessageType.merge => '[聊天记录] $mergeMessageCount条消息',
      MessageType.system => _systemDisplayText(json),
      _ => content,
    };
  }

  String _systemDisplayText(Map<String, dynamic> json) =>
      _readableSystemMessage(json, content);

  /// 发送时间 DateTime
  DateTime get sendDateTime {
    final t = sendTime.toInt();
    return t > 0
        ? DateTime.fromMillisecondsSinceEpoch(t)
        : DateTime.fromMillisecondsSinceEpoch(createTime.toInt());
  }

  /// 消息发送状态（仅自己发的消息有效）
  MessageSendStatus? get messageSendStatus =>
      MessageSendStatus.fromValue(status);

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
  String get videoSource {
    if (videoPath.isNotEmpty) return videoPath;
    return parsedContent['videoUrl'] as String? ?? '';
  }

  String get videoSnapshotPath =>
      parsedContent['snapshotPath'] as String? ?? '';
  int get videoDuration => parsedContent['duration'] as int? ?? 0;
  int get videoSize => parsedContent['size'] as int? ?? 0;

  // ---- 语音 ----
  String get soundPath => parsedContent['soundPath'] as String? ?? '';
  String get soundSource {
    if (soundPath.isNotEmpty) return soundPath;
    return parsedContent['sourceUrl'] as String? ?? '';
  }

  int get audioDuration => parsedContent['duration'] as int? ?? 0;
  int get audioDataSize => parsedContent['dataSize'] as int? ?? 0;

  // ---- 文件 ----
  String get filePath => parsedContent['filePath'] as String? ?? '';
  String get fileSource {
    if (filePath.isNotEmpty) return filePath;
    return parsedContent['sourceUrl'] as String? ??
        parsedContent['url'] as String? ??
        '';
  }

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
  double get longitude =>
      (parsedContent['longitude'] as num?)?.toDouble() ?? 0.0;

  // ---- 名片 ----
  String get cardUserId => parsedContent['userID'] as String? ?? '';
  String get cardNickname => parsedContent['nickname'] as String? ?? '';
  String get cardFaceUrl => parsedContent['faceUrl'] as String? ?? '';

  // ---- 合并转发 ----
  String get mergeTitle => parsedContent['title'] as String? ?? '';
  int get mergeMessageCount {
    final list = parsedContent['multiMessage'];
    if (list is List) return list.length;
    return 0;
  }

  List<String> get mergeSenderNicknames {
    final list = parsedContent['abstractList'];
    if (list is List) return list.cast<String>();
    return [];
  }

  // ---- 引用 ----
  String get quoteText => parsedContent['text'] as String? ?? '';
  String get quoteReplyMessageId =>
      parsedContent['replyMessageId'] as String? ?? '';
  String get quoteSenderNickname =>
      parsedContent['senderNickname'] as String? ?? '';
  int get quoteReplyContentType =>
      parsedContent['replyMessageContentType'] as int? ?? 0;
  String get quoteReplyContent =>
      parsedContent['replyMessageContent'] as String? ?? '';

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
    final size = fileSize > 0
        ? fileSize
        : (videoSize > 0 ? videoSize : imageOrFileSize);
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 给 Rust 生成的 LocalChatLog 添加 UI 展示文本
extension LocalChatLogExt on LocalChatLog {
  MessageType get messageType => messageTypeFromContentType(contentType);

  Map<String, dynamic> get parsedContent {
    if (content.isEmpty || !content.startsWith('{')) return {};
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String get displayText {
    final json = parsedContent;
    return switch (messageType) {
      MessageType.text => json['content'] as String? ?? content,
      MessageType.advancedText => json['content'] as String? ?? '',
      MessageType.markdown => json['content'] as String? ?? '',
      MessageType.quote => json['text'] as String? ?? '',
      MessageType.at => json['text'] as String? ?? '',
      MessageType.image => '[图片]',
      MessageType.video => '[视频]',
      MessageType.audio => '[语音]',
      MessageType.file => '[文件]',
      MessageType.location => '[位置]',
      MessageType.card => '[名片]',
      MessageType.merge => '[聊天记录]',
      MessageType.system => _systemDisplayText(json),
      _ => content,
    };
  }

  String _systemDisplayText(Map<String, dynamic> json) =>
      _readableSystemMessage(json, content);
}

String _readableSystemMessage(Map<String, dynamic> json, String fallback) {
  if (json.containsKey('revokerID') || json.containsKey('revokerNickname')) {
    final nickname = json['revokerNickname'] as String?;
    return '$nickname 撤回了一条消息';
  }
  if (json.containsKey('content')) {
    final value = json['content'];
    if (value is String && value.isNotEmpty && !value.contains('"')) {
      return value;
    }
  }
  for (final key in ['detail', 'msgTips', 'tips', 'text']) {
    final value = json[key];
    if (value is! String || value.isEmpty) continue;
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          final readable = _firstReadableMessageField(decoded);
          if (readable != null) return readable;
        }
      } catch (_) {}
    } else if (!value.contains('"')) {
      return value;
    }
  }
  if (fallback.isNotEmpty && !fallback.contains('"')) return fallback;
  return '[系统消息]';
}

String? _firstReadableMessageField(Map<String, dynamic> map) {
  for (final field in [
    'reqMsg',
    'content',
    'msgTips',
    'tips',
    'text',
    'nickname',
    'fromNickname',
    'toNickname',
    'handleMsg',
  ]) {
    final item = map[field];
    if (item is String && item.isNotEmpty) return item;
  }
  final request = map['request'];
  if (request is Map<String, dynamic>) {
    return _firstReadableMessageField(request);
  }
  return null;
}

/// 从 messageSent 事件构造 MessageInfo
ChatMessage messageSentToChatMessage({
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
}) => ChatMessage(
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

/// 将合并转发 `multiMessage` 中的子消息 JSON 还原为 [MessageInfo]。
///
/// 兼容两种序列化来源：
/// - 本 SDK（Rust `MsgStruct` camelCase）：`clientMsgId` / `sendId` / `groupId` ...
/// - Go SDK（`openim-sdk-core` `MsgStruct`）：`clientMsgID` / `sendID` / `groupID` ...
ChatMessage mergeSubMessageFromJson(Map<String, dynamic> json) {
  String pickString(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  int pickInt(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  bool pickBool(List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is bool) return v;
    }
    return false;
  }

  // Go SDK 在 msgHandleByContentType 解析后会把 content 清空、只保留 typed elem
  // （pictureElem/textElem 等）。这里若 content 为空，则把 typed elem 编码回
  // content JSON，保证 UI 层按 content 解析仍能拿到图片/文本等数据。
  var content = pickString(['content']);
  if (content.isEmpty) {
    content = _mergeSubElemToContent(json);
  }

  final sessionType = pickInt(['sessionType']);
  return ChatMessage(
    clientMsgId: pickString(['clientMsgID', 'clientMsgId']),
    serverMsgId: pickString(['serverMsgID', 'serverMsgId']),
    sendId: pickString(['sendID', 'sendId']),
    recvId: pickString(['recvID', 'recvId']),
    groupId: pickString(['groupID', 'groupId']),
    senderPlatformId: pickInt(['senderPlatformID', 'senderPlatformId']),
    senderNickname: pickString(['senderNickname']),
    senderFaceUrl: pickString(['senderFaceUrl', 'senderFaceURL']),
    sessionType: sessionType != 0 ? sessionType : 1,
    msgFrom: pickInt(['msgFrom']),
    contentType: pickInt(['contentType']),
    content: content,
    seq: pickInt(['seq']),
    sendTime: pickInt(['sendTime']),
    createTime: pickInt(['createTime']),
    status: pickInt(['status']),
    isRead: pickBool(['isRead']),
    attachedInfo: pickString(['attachedInfo']),
    ex: pickString(['ex']),
  );
}

/// Go SDK 会把合并消息子消息的 content 置空、仅保留 typed elem，
/// 这里把第一个非空 typed elem 编码回 content JSON（对齐官方 Web 的
/// `message.pictureElem.sourcePicture.url` 读取方式）。
String _mergeSubElemToContent(Map<String, dynamic> json) {
  const elemKeys = [
    'textElem',
    'pictureElem',
    'soundElem',
    'videoElem',
    'fileElem',
    'atTextElem',
    'quoteElem',
    'mergeElem',
    'cardElem',
    'locationElem',
    'faceElem',
    'customElem',
    'advancedTextElem',
    'markdownTextElem',
  ];
  for (final key in elemKeys) {
    final elem = json[key];
    if (elem is Map<String, dynamic> && elem.isNotEmpty) {
      return jsonEncode(elem);
    }
  }
  return '';
}

/// 按发送时间升序排序，时间相同时按 seq 升序。
///
/// UI 使用 reverse ListView，列表必须保持“旧消息在前、新消息在后”，
/// 这样渲染时最新消息才会出现在底部。
List<ChatMessage> sortMessagesByTime(List<ChatMessage> messages) {
  final list = List<ChatMessage>.from(messages);
  list.sort((a, b) {
    final time = a.sendTime.toInt().compareTo(b.sendTime.toInt());
    if (time != 0) return time;
    return a.seq.toInt().compareTo(b.seq.toInt());
  });
  return list;
}
