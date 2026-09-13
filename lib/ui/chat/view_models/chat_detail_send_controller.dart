import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/chat/message_service_notifier.dart';
import '../../../application/chat/send_media_use_case.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/friend.dart';
import '../../../providers/chat_aux_provider.dart';
import '../../contacts/providers/friend_provider.dart';
import '../providers/message_provider.dart';
import '../providers/message_service_provider.dart';
import '../widgets/message_content_type.dart' show MessageContentType;
import 'chat_detail_view_model.dart';

/// 聊天详情页发送与媒体操作：文本/@/引用/Markdown、图片、视频、语音、文件、位置、名片。
class ChatDetailSendController {
  ChatDetailSendController({
    required this.ref,
    required this.conversationId,
    required this.readSendTarget,
    required this.readState,
    required this.updateState,
  });

  final Ref ref;
  final String conversationId;
  final ChatSendTarget? Function() readSendTarget;
  final ChatDetailState Function() readState;
  final void Function(ChatDetailState Function(ChatDetailState)) updateState;

  MessageServiceNotifier get _messageService =>
      ref.read(messageServiceProvider.notifier);

  ChatDetailState get _state => readState();

  /// 发送文本类消息。
  ///
  /// 返回「本地是否已受理」：消息先乐观上屏（气泡立刻出现，发送中转圈），
  /// 网络结果由发送链路异步收敛——失败时气泡标红、可点重发，并写入
  /// `MessageListState.error` 供页面提示。因此断网也能看到消息与失败状态，
  /// 而不是「没有任何反应」。
  Future<bool> sendText(String text, MessageContentType type) async {
    if (text.trim().isEmpty) return false;
    final target = readSendTarget();
    if (target == null) {
      updateState((s) => s.copyWith(errorText: '无法发送：会话缺少对方 ID，请返回会话列表重试'));
      return false;
    }

    final quotedMsg = _state.quotedMessage;
    final atUserIds = List<String>.from(_state.atUserIds);
    final messages = ref.read(messageListProvider(conversationId).notifier);
    final Future<bool> sent;
    if (atUserIds.isNotEmpty) {
      updateState((s) => s.copyWith(atUserIds: const []));
      sent = messages.sendAtTextMessage(
        recvId: target.recvId,
        text: text,
        atUserIds: atUserIds,
        sessionType: target.sessionType,
        groupId: target.groupId,
      );
    } else if (quotedMsg != null) {
      updateState((s) => s.copyWith(clearQuotedMessage: true));
      sent = _sendQuoted(text: text, target: target, quoted: quotedMsg);
    } else if (type == MessageContentType.markdown) {
      sent = messages.sendMarkdownMessage(
        recvId: target.recvId,
        text: text,
        sessionType: target.sessionType,
        groupId: target.groupId,
      );
    } else {
      sent = messages.sendTextMessage(
        recvId: target.recvId,
        text: text,
        sessionType: target.sessionType,
        groupId: target.groupId,
      );
    }

    final accepted = await sent;
    updateState(
      (s) => accepted
          ? s.copyWith(clearError: true)
          : s.copyWith(
              errorText:
                  ref.read(messageListProvider(conversationId)).error ??
                  '发送消息失败',
            ),
    );
    return accepted;
  }

  Future<bool> _sendQuoted({
    required String text,
    required ChatSendTarget target,
    required ChatMessage quoted,
  }) async {
    try {
      await _messageService.sendQuoteMessage(
        text: text,
        sourceId: target.recvId,
        sessionType: target.sessionType,
        quoted: quoted,
        conversationId: conversationId,
      );
      return true;
    } catch (e) {
      updateState((s) => s.copyWith(errorText: '发送消息失败: $e'));
      return false;
    }
  }

  Future<bool> sendImage(String filePath) => _sendMedia(
    (target) => ref
        .read(messageListProvider(conversationId).notifier)
        .sendImageMessage(
          recvId: target.recvId,
          filePath: filePath,
          sessionType: target.sessionType,
          groupId: target.groupId,
        ),
  );

  /// 发送 GIF（URL 图片，内容已上传）
  Future<bool> sendGif(String url) => _sendMedia(
    (target) => ref
        .read(messageListProvider(conversationId).notifier)
        .sendImageMessageFromUrl(
          recvId: target.recvId,
          sourceUrl: url,
          sessionType: target.sessionType,
          groupId: target.groupId,
        ),
  );

  Future<bool> sendVideo({
    required String videoPath,
    required String snapshotPath,
    required int duration,
  }) => _sendMedia(
    (target) => ref
        .read(messageListProvider(conversationId).notifier)
        .sendVideoMessage(
          recvId: target.recvId,
          videoPath: videoPath,
          snapshotPath: snapshotPath,
          sessionType: target.sessionType,
          duration: duration,
          groupId: target.groupId,
        ),
  );

  Future<bool> sendVoice(String filePath, int duration) => _sendMedia(
    (target) => ref
        .read(messageListProvider(conversationId).notifier)
        .sendSoundMessage(
          recvId: target.recvId,
          filePath: filePath,
          sessionType: target.sessionType,
          duration: duration,
          groupId: target.groupId,
        ),
  );

  Future<bool> sendFile(String filePath) => _sendMedia(
    (target) => ref
        .read(messageListProvider(conversationId).notifier)
        .sendFileMessage(
          recvId: target.recvId,
          filePath: filePath,
          sessionType: target.sessionType,
          groupId: target.groupId,
        ),
  );

  Future<bool> sendLocation({
    required String description,
    required double latitude,
    required double longitude,
  }) => _sendMedia(
    (target) => ref
        .read(messageListProvider(conversationId).notifier)
        .sendLocationMessage(
          recvId: target.recvId,
          description: description,
          latitude: latitude,
          longitude: longitude,
          sessionType: target.sessionType,
          groupId: target.groupId,
        ),
  );

  Future<bool> sendCard(Friend friend) async {
    final target = readSendTarget();
    if (target == null) {
      updateState((s) => s.copyWith(errorText: '会话信息异常'));
      return false;
    }
    try {
      await _messageService.sendCardMessage(
        userId: friend.userId,
        nickname: friend.nickname,
        faceUrl: friend.faceUrl,
        ex: '',
        sourceId: target.recvId,
        sessionType: target.sessionType,
        conversationId: conversationId,
      );
      return true;
    } catch (e) {
      updateState((s) => s.copyWith(errorText: '发送名片失败: $e'));
      return false;
    }
  }

  Future<List<Friend>> loadFriendsForPicker() async {
    final friendState = ref.read(friendListProvider);
    if (friendState.friends.isEmpty && !friendState.isLoading) {
      await ref.read(friendListProvider.notifier).loadFriends();
    }
    return ref.read(friendListProvider).friends;
  }

  Future<bool> openFile({
    required String source,
    required String fileName,
  }) async {
    try {
      return await ref
          .read(chatAuxRepositoryProvider)
          .openFile(source: source, fileName: fileName);
    } catch (e) {
      updateState((s) => s.copyWith(errorText: '打开文件失败: $e'));
      return false;
    }
  }

  Future<bool> _sendMedia(Future<bool> Function(ChatSendTarget target) send) {
    return const SendMediaUseCase().send(
      readTarget: readSendTarget,
      run: send,
      readError: () => ref.read(messageListProvider(conversationId)).error,
      onError: (message) => updateState((s) => s.copyWith(errorText: message)),
    );
  }
}
