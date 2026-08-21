import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/chat/message_service_notifier.dart';
import '../../../domain/models/friend.dart';
import '../../../providers/chat_aux_provider.dart';
import '../../../providers/connection_provider.dart';
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

  Future<bool> sendText(String text, MessageContentType type) async {
    if (text.trim().isEmpty) return false;
    if (!ref.read(connectionProvider).isConnected) {
      updateState((s) => s.copyWith(errorText: 'WebSocket 未连接，无法发送消息'));
      return false;
    }
    final target = readSendTarget();
    if (target == null) {
      updateState((s) => s.copyWith(errorText: '无法发送：会话缺少对方 ID，请返回会话列表重试'));
      return false;
    }

    try {
      final quotedMsg = _state.quotedMessage;
      final atUserIds = List<String>.from(_state.atUserIds);
      if (atUserIds.isNotEmpty) {
        updateState((s) => s.copyWith(atUserIds: const []));
        await ref
            .read(messageListProvider(conversationId).notifier)
            .sendAtTextMessage(
              recvId: target.recvId,
              text: text,
              atUserIds: atUserIds,
              sessionType: target.sessionType,
              groupId: target.groupId,
            );
      } else if (quotedMsg != null) {
        updateState((s) => s.copyWith(clearQuotedMessage: true));
        await _messageService.sendQuoteMessage(
          text: text,
          sourceId: target.recvId,
          sessionType: target.sessionType,
          quoteText: quotedMsg.content,
          quoteClientMsgId: quotedMsg.clientMsgId,
          quoteSendId: quotedMsg.sendId,
          quoteSendTime: quotedMsg.sendTime.toInt(),
        );
      } else if (type == MessageContentType.markdown) {
        await ref
            .read(messageListProvider(conversationId).notifier)
            .sendMarkdownMessage(
              recvId: target.recvId,
              text: text,
              sessionType: target.sessionType,
              groupId: target.groupId,
            );
      } else {
        await ref
            .read(messageListProvider(conversationId).notifier)
            .sendTextMessage(
              recvId: target.recvId,
              text: text,
              sessionType: target.sessionType,
              groupId: target.groupId,
            );
      }
      updateState((s) => s.copyWith(clearError: true));
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

  Future<bool> _sendMedia(
    Future<bool> Function(ChatSendTarget target) send,
  ) async {
    final target = readSendTarget();
    if (target == null) {
      updateState((s) => s.copyWith(errorText: '会话信息异常'));
      return false;
    }
    final ok = await send(target);
    if (!ok) {
      final error = ref.read(messageListProvider(conversationId)).error;
      updateState((s) => s.copyWith(errorText: error ?? '发送失败'));
    }
    return ok;
  }
}
