import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import '../../../data/mappers/message_mapper.dart' show messageFromMsgStruct;
import '../../../data/repositories/message_repository.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../../domain/models/message.dart' show MessageSendStatus;
import '../../../generated/rust/constant/enums.dart' show SessionType;
import '../../../generated/rust/model/msg_struct.dart' show MsgStruct;
import 'message_service_notifier.dart';

/// 一次发送的「本地受理结果」。
///
/// 对齐 Go SDK / 官方 Demo 的发送时序：
/// `CreateXxxMessage`（本地消息，clientMsgId 已生成）→ 上屏（[message]）→ `SendMessage`（[done]）。
/// UI 拿到 [message] 即可清空输入框、滚动到底；网络结果由 [done] 异步收敛。
@immutable
class PendingSend {
  const PendingSend({required this.message, required this.done});

  /// 已乐观上屏的本地消息（status=sending，clientMsgId 与最终回执一致）。
  final ChatMessage message;

  /// 网络发送结果：成功为服务端确认后的消息，失败抛异常（此时气泡已标为失败）。
  final Future<ChatMessage> done;
}

/// 消息发送链路（唯一发送入口）。
///
/// 一次发送固定走四步，与 Go SDK 一一对应：
/// 1. `create`：本地构造消息（Rust `CreateXxxMessage`，已带 clientMsgId）；
/// 2. 乐观上屏：立刻写入状态（status=sending），UI 无需等待网络；
/// 3. `send`：Rust `SendMessage` 发送**同一条**消息；
/// 4. 状态收敛：成功就地更新服务端字段（serverMsgId/seq/sendTime/status），
///    失败把同一条标记为 failed（可点重发，不新增气泡）。
///
/// 新增消息类型只需在 Rust builder + 调用处 + 内容渲染各加一步，状态机不用改。
class MessageSendPipeline {
  MessageSendPipeline({
    required this.service,
    required this.repository,
    required this.isClientReady,
  });

  final MessageServiceNotifier service;
  final MessageRepository repository;
  final bool Function() isClientReady;

  SessionType _sdkSessionType(ChatSessionType type) =>
      SessionType.values[type.index];

  bool _isGroup(ChatSessionType type) =>
      type == ChatSessionType.writeGroupChat ||
      type == ChatSessionType.readGroupChat;

  void _ensureReady() {
    if (!isClientReady()) throw StateError('客户端未初始化');
  }

  // ==========================================================================
  // 各消息类型入口（对齐 Go SDK CreateXxxMessage + SendMessage）
  // ==========================================================================

  Future<PendingSend> sendText({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String text,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createTextMessage(text: text),
  );

  Future<PendingSend> sendMarkdown({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String text,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createMarkdownMessage(text: text),
  );

  Future<PendingSend> sendAtText({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String text,
    required List<String> atUserIds,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () =>
        repository.createAtTextMessage(text: text, atUserIds: atUserIds),
  );

  Future<PendingSend> sendQuote({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String text,
    required ChatMessage quoted,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createQuoteMessage(text: text, quoted: quoted),
  );

  Future<PendingSend> sendImage({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String filePath,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createImageMessage(filePath: filePath),
  );

  Future<PendingSend> sendImageFromUrl({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String sourceUrl,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createImageMessageFromUrl(sourceUrl: sourceUrl),
  );

  Future<PendingSend> sendVideo({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String videoPath,
    required String snapshotPath,
    required int duration,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createVideoMessage(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
      duration: duration,
    ),
  );

  Future<PendingSend> sendSound({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String filePath,
    required int duration,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () =>
        repository.createSoundMessage(filePath: filePath, duration: duration),
  );

  Future<PendingSend> sendFile({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String filePath,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createFileMessage(filePath: filePath),
  );

  Future<PendingSend> sendLocation({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String description,
    required double latitude,
    required double longitude,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createLocationMessage(
      description: description,
      latitude: latitude,
      longitude: longitude,
    ),
  );

  Future<PendingSend> sendFace({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required int index,
    required String data,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createFaceMessage(index: index, data: data),
  );

  Future<PendingSend> sendCard({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required String userId,
    required String nickname,
    required String faceUrl,
    required String ex,
  }) => _prepare(
    conversationId: conversationId,
    sourceId: sourceId,
    sessionType: sessionType,
    create: () => repository.createCardMessage(
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      ex: ex,
    ),
  );

  /// 重发失败消息（对齐官方 Demo `_sendMessage(message..status = sending, addToUI: false)`）：
  /// 只把同一条置回 sending，不新增气泡；Rust 侧按同一 clientMsgId 重发。
  Future<PendingSend> resend({
    required String conversationId,
    required ChatMessage message,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    _ensureReady();
    service.applySendStatus(
      conversationId,
      message.clientMsgId,
      MessageSendStatus.sending.value,
    );
    final resending = message.copyWith(status: MessageSendStatus.sending.value);
    final done = _resend(
      resending,
      conversationId: conversationId,
      sourceId: sourceId,
      sessionType: sessionType,
    );
    unawaited(done.then<void>((_) {}, onError: (Object _) {}));
    return PendingSend(message: resending, done: done);
  }

  // ==========================================================================
  // 内部：构造 → 乐观上屏 → 发送 → 状态收敛
  // ==========================================================================

  Future<PendingSend> _prepare({
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
    required Future<MsgStruct> Function() create,
  }) async {
    _ensureReady();
    final local = await create();
    final message = localMessage(
      local,
      sourceId: sourceId,
      sessionType: sessionType,
    );
    service.upsertSentMessage(conversationId, message);
    final done = _send(
      local,
      conversationId: conversationId,
      sourceId: sourceId,
      sessionType: sessionType,
    );
    // 失败已写入消息状态（气泡标红、可重发）；这里保证即使调用方不监听
    // done，也不会产生未处理的异步异常。
    unawaited(done.then<void>((_) {}, onError: (Object _) {}));
    return PendingSend(message: message, done: done);
  }

  Future<ChatMessage> _send(
    MsgStruct local, {
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    try {
      final sent = await repository.sendPreparedMessage(
        message: local,
        sourceId: sourceId,
        sessionType: _sdkSessionType(sessionType),
      );
      service.mergeSentMessage(conversationId, local.clientMsgId, sent);
      return sent;
    } catch (e) {
      _markFailed(conversationId, local.clientMsgId);
      rethrow;
    }
  }

  Future<ChatMessage> _resend(
    ChatMessage message, {
    required String conversationId,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    try {
      final sent = await repository.resendMessage(
        message: message,
        sourceId: sourceId,
        sessionType: _sdkSessionType(sessionType),
      );
      service.mergeSentMessage(conversationId, message.clientMsgId, sent);
      return sent;
    } catch (e) {
      _markFailed(conversationId, message.clientMsgId);
      rethrow;
    }
  }

  void _markFailed(String conversationId, String clientMsgId) {
    service.applySendStatus(
      conversationId,
      clientMsgId,
      MessageSendStatus.sendFailed.value,
    );
  }

  /// 本地消息 → 领域消息（补齐会话信息与自身昵称/头像，供气泡立刻渲染）。
  @visibleForTesting
  ChatMessage localMessage(
    MsgStruct local, {
    required String sourceId,
    required ChatSessionType sessionType,
  }) {
    final base = messageFromMsgStruct(local);
    final profile = service.currentState.loginUserProfile;
    final isGroup = _isGroup(sessionType);
    return base.copyWith(
      sendId: base.sendId.isNotEmpty
          ? base.sendId
          : service.currentState.currentUserId,
      recvId: isGroup ? '' : sourceId,
      groupId: isGroup ? sourceId : '',
      sessionType: sessionType.index + 1,
      status: MessageSendStatus.sending.value,
      senderNickname: base.senderNickname.isNotEmpty
          ? base.senderNickname
          : (profile?.nickname ?? ''),
      senderFaceUrl: base.senderFaceUrl.isNotEmpty
          ? base.senderFaceUrl
          : (profile?.faceUrl ?? ''),
    );
  }
}
