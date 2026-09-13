import '../../domain/models/chat_message.dart' show ChatMessage;
import '../../generated/rust/ffi/client.dart' show OpenImBridgeClient;
import '../../generated/rust/constant/enums.dart' show SessionType;
import '../../generated/rust/ffi/message.dart' as ffi_message;
import '../../generated/rust/ffi/message_advanced.dart' as ffi_message_advanced;
import '../../generated/rust/ffi/message_builder.dart' as ffi_message_builder;
import '../../generated/rust/http/message.dart' show RevokeMessageReq;
import '../../generated/rust/model/msg_struct.dart'
    show MsgStruct, PictureBaseInfo, CardElem;
import '../mappers/message_mapper.dart'
    show messageFromMsgStruct, msgStructFromChatMessage;

/// 消息发送类 Repository 实现：文本/Markdown/@、媒体、转发、撤回、删除与重发。
mixin MessageRepositorySendMixin on Object {
  OpenImBridgeClient get client;

  // ==========================================================================
  // 本地消息构造（对齐 Go SDK CreateXxxMessage：不发网络，先拿到带 clientMsgId
  // 的本地消息，供上层乐观上屏；随后由 sendPreparedMessage 发送同一条消息）
  // ==========================================================================

  Future<ChatMessage> sendTextMessage({
    required String text,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    final msg = await createTextMessage(text: text);
    return sendPreparedMessage(
      message: msg,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  /// 构造本地文本消息（对齐 Go `CreateTextMessage`）：不发网络，
  /// 供上层乐观上屏（status=sending，clientMsgId 由本地生成）。
  Future<MsgStruct> createTextMessage({required String text}) =>
      ffi_message_builder.createTextMessage(text: text);

  /// 构造本地 Markdown 消息（对齐 Go `CreateMarkdownMessage`）
  Future<MsgStruct> createMarkdownMessage({required String text}) =>
      ffi_message_builder.createMarkdownMessage(text: text);

  /// 构造本地 @ 消息（对齐 Go `CreateTextAtMessage`）
  Future<MsgStruct> createAtTextMessage({
    required String text,
    required List<String> atUserIds,
  }) => ffi_message_builder.createAtTextMessage(
    text: text,
    atUserList: atUserIds,
    atUsersInfo: const [],
    quoteMsg: null,
  );

  /// 构造本地图片消息（对齐 Go SDK `CreateImageMessageFromFullPath`）
  Future<MsgStruct> createImageMessage({required String filePath}) =>
      ffi_message_builder.createImageMessageFromFullPath(
        imageFullPath: filePath,
      );

  /// 构造内容已上传的 URL 图片消息（对齐 Go SDK `CreateImageMessageByURL`）
  Future<MsgStruct> createImageMessageFromUrl({required String sourceUrl}) {
    final picture = PictureBaseInfo(
      width: 0,
      height: 0,
      pictureType: '',
      size: 0,
      url: sourceUrl,
      uuid: '',
    );
    return ffi_message_builder.createImageMessageByUrl(
      sourcePath: '',
      sourcePicture: picture,
      bigPicture: picture,
      snapshotPicture: picture,
    );
  }

  /// 构造本地视频消息（对齐 Go SDK `CreateVideoMessageFromFullPath`）
  Future<MsgStruct> createVideoMessage({
    required String videoPath,
    required String snapshotPath,
    required int duration,
  }) => ffi_message_builder.createVideoMessageFromFullPath(
    videoFullPath: videoPath,
    videoType: extensionOf(videoPath),
    duration: duration,
    snapshotFullPath: snapshotPath,
  );

  /// 构造本地语音消息（对齐 Go SDK `CreateSoundMessageFromFullPath`）
  Future<MsgStruct> createSoundMessage({
    required String filePath,
    required int duration,
  }) => ffi_message_builder.createSoundMessageFromFullPath(
    soundPath: filePath,
    duration: duration,
  );

  /// 构造本地文件消息（对齐 Go SDK `CreateFileMessageFromFullPath`）
  Future<MsgStruct> createFileMessage({required String filePath}) =>
      ffi_message_builder.createFileMessageFromFullPath(
        fileFullPath: filePath,
        fileName: fileNameOf(filePath),
      );

  /// 构造本地位置消息（对齐 Go SDK `CreateLocationMessage`）
  Future<MsgStruct> createLocationMessage({
    required String description,
    required double latitude,
    required double longitude,
  }) => ffi_message_builder.createLocationMessage(
    description: description,
    longitude: longitude,
    latitude: latitude,
  );

  /// 构造本地表情消息（对齐 Go SDK `CreateFaceMessage`）
  Future<MsgStruct> createFaceMessage({
    required int index,
    required String data,
  }) => ffi_message_builder.createFaceMessage(index: index, data: data);

  /// 构造本地名片消息（对齐 Go SDK `CreateCardMessage`）
  Future<MsgStruct> createCardMessage({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
  }) => ffi_message_builder.createCardMessage(
    elem: CardElem(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
    ),
  );

  /// 构造本地引用消息（对齐 Go SDK `CreateQuoteMessage`）
  Future<MsgStruct> createQuoteMessage({
    required String text,
    required ChatMessage quoted,
  }) => ffi_message_builder.createQuoteMessage(
    text: text,
    quotedMsg: msgStructFromChatMessage(quoted),
  );

  /// 发送已构建的本地消息（对齐 Go `SendMessage`）
  Future<ChatMessage> sendPreparedMessage({
    required MsgStruct message,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        msgStruct: message,
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message_advanced.forwardMessageByClientId(
      clientMsgId: clientMsgId,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  Future<void> sendTyping({
    required String sourceId,
    required SessionType sessionType,
    required bool focus,
  }) {
    return ffi_message_advanced.sendTyping(
      sourceId: sourceId,
      sessionType: sessionType,
      focus: focus,
    );
  }

  Future<void> sendMergerMessage({
    required List<String> clientMsgIds,
    required String sourceConversationId,
    required String title,
    required List<String> summaryList,
    required String sourceId,
    required SessionType sessionType,
  }) {
    return ffi_message.sendMergerMessage(
      clientMsgIds: clientMsgIds,
      sourceConversationId: sourceConversationId,
      title: title,
      summaryList: summaryList,
      sourceId: sourceId,
      sessionType: sessionType,
    );
  }

  Future<ChatMessage> resendMessage({
    required ChatMessage message,
    required String sourceId,
    required SessionType sessionType,
  }) async {
    return messageFromMsgStruct(
      await ffi_message_advanced.sendMessage(
        // 重发沿用原 clientMsgId / 原时间，服务端按同一 ID 去重，不会产生重复消息
        msgStruct: msgStructFromChatMessage(message),
        sourceId: sourceId,
        sessionType: sessionType,
      ),
    );
  }

  Future<void> revokeMessage({
    required String conversationId,
    required String userId,
    required int seq,
    required String clientMsgId,
    required int sessionType,
  }) {
    return client.revokeMessage(
      req: RevokeMessageReq(
        conversationId: conversationId,
        userId: userId,
        seq: seq,
        clientMsgId: clientMsgId,
        sessionType: sessionType,
      ),
    );
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String clientMsgId,
  }) {
    return ffi_message_advanced.deleteMessage(
      conversationId: conversationId,
      clientMsgId: clientMsgId,
    );
  }
}

/// 从路径提取文件名（跨平台，支持 / 与 \ 分隔符）
String fileNameOf(String path) {
  final separator = path.contains('\\') ? '\\' : '/';
  return path.split(separator).last;
}

/// 从路径提取扩展名（不含点，无扩展名返回空串）
String extensionOf(String path) {
  final name = fileNameOf(path);
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1);
}
