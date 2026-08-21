import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/friend.dart';
import '../../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../providers/chat_aux_provider.dart';
import '../../../providers/connection_provider.dart';
import '../../../providers/current_user_provider.dart';
import '../../contacts/providers/friend_provider.dart';
import '../../../ui/core/extensions/conversation_extensions.dart';
import '../providers/message_provider.dart';
import '../providers/message_service_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/message_content_type.dart' show MessageContentType;
import '../../../application/chat/message_service_notifier.dart';
import 'chat_detail_forward_mixin.dart';
import 'chat_detail_selection_mixin.dart';

typedef ChatSendTarget = ({
  String recvId,
  ChatSessionType sessionType,
  String groupId,
});

/// 聊天详情页业务状态
class ChatDetailState {
  final bool isLoading;
  final bool hasMoreHistory;
  final ChatMessage? quotedMessage;
  final bool selectMode;
  final List<ChatMessage> selectedMessages;
  final List<String> atUserIds;
  final String? errorText;
  final bool isForwarding;
  final int forwardDone;
  final int forwardTotal;

  const ChatDetailState({
    this.isLoading = false,
    this.hasMoreHistory = true,
    this.quotedMessage,
    this.selectMode = false,
    this.selectedMessages = const [],
    this.atUserIds = const [],
    this.errorText,
    this.isForwarding = false,
    this.forwardDone = 0,
    this.forwardTotal = 0,
  });

  ChatDetailState copyWith({
    bool? isLoading,
    bool? hasMoreHistory,
    ChatMessage? quotedMessage,
    bool clearQuotedMessage = false,
    bool? selectMode,
    List<ChatMessage>? selectedMessages,
    List<String>? atUserIds,
    String? errorText,
    bool clearError = false,
    bool? isForwarding,
    int? forwardDone,
    int? forwardTotal,
  }) {
    return ChatDetailState(
      isLoading: isLoading ?? this.isLoading,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      quotedMessage: clearQuotedMessage
          ? null
          : (quotedMessage ?? this.quotedMessage),
      selectMode: selectMode ?? this.selectMode,
      selectedMessages: selectedMessages ?? this.selectedMessages,
      atUserIds: atUserIds ?? this.atUserIds,
      errorText: clearError ? null : (errorText ?? this.errorText),
      isForwarding: isForwarding ?? this.isForwarding,
      forwardDone: forwardDone ?? this.forwardDone,
      forwardTotal: forwardTotal ?? this.forwardTotal,
    );
  }

  Set<String> get selectedClientMsgIds =>
      selectedMessages.map((m) => m.clientMsgId).toSet();
}

/// 聊天详情页 ViewModel：负责消息加载、发送、草稿、已读、引用、多选、转发、搜索等业务。
class ChatDetailViewModel extends FamilyNotifier<ChatDetailState, String>
    with ChatDetailSelectionMixin, ChatDetailForwardMixin {
  DateTime? _lastTypingSent;
  DateTime? _lastMarkReadTime;
  String? _onlineStatusUserId;
  @override
  ChatDetailState build(String conversationId) {
    return const ChatDetailState();
  }

  MessageServiceNotifier get _messageService =>
      ref.read(messageServiceProvider.notifier);

  Conversation? get conversation {
    final conversations = ref.read(conversationListProvider).conversations;
    try {
      return conversations.firstWhere((c) => c.conversationId == arg);
    } catch (_) {
      return null;
    }
  }

  bool get isGroup {
    final conv = conversation;
    return conv?.conversationType == 2 || conv?.conversationType == 3;
  }

  String get currentUserId {
    final loginUserId = ref.read(currentUserIdProvider);
    if (loginUserId.isNotEmpty) {
      return loginUserId;
    }
    return ref.read(messageServiceProvider).currentUserId;
  }

  String? get draftText {
    final conv = conversation;
    if (conv == null || conv.draftText.isEmpty) return null;
    try {
      final map = jsonDecode(conv.draftText) as Map<String, dynamic>?;
      final text = map?['text'] as String?;
      return (text != null && text.isNotEmpty) ? text : conv.draftText;
    } catch (_) {
      return conv.draftText;
    }
  }

  ChatSendTarget? get sendTarget {
    final conv = conversation;
    if (conv == null) return null;
    final cid = conv.conversationId;
    final type = conv.conversationType;
    final myId = currentUserId;
    String recvId;
    switch (type) {
      case 1:
        recvId = conv.userId;
        if (recvId.isEmpty && cid.startsWith('si_')) {
          final parts = cid.split('_');
          if (parts.length >= 3) {
            recvId = parts[1] == myId ? parts[2] : parts[1];
          }
        }
      case 2:
        recvId = cid.startsWith('g_') ? cid.substring(2) : conv.groupId;
      case 3:
        recvId = cid.startsWith('sg_') ? cid.substring(3) : conv.groupId;
      default:
        recvId = '';
    }
    if (recvId.isEmpty) return null;

    final sessionType = conv.sessionType;
    final groupId =
        (sessionType == ChatSessionType.writeGroupChat ||
            sessionType == ChatSessionType.readGroupChat)
        ? (conv.groupId.isNotEmpty
              ? conv.groupId
              : cid.startsWith('sg_')
              ? cid.substring(3)
              : cid.startsWith('g_')
              ? cid.substring(2)
              : '')
        : '';
    return (recvId: recvId, sessionType: sessionType, groupId: groupId);
  }

  Future<void> loadMessages({bool isLoadMore = false}) async {
    if (state.isLoading || (!state.hasMoreHistory && isLoadMore)) return;

    final currentMessages = ref.read(messagesByConversationProvider(arg));
    String startClientMsgId = '';
    if (isLoadMore && currentMessages.isNotEmpty) {
      startClientMsgId = currentMessages.first.clientMsgId;
    }

    if (!isLoadMore) {
      ref.read(messageListProvider(arg).notifier).resetLoadState();
    }
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final hasMore = await ref
          .read(messageListProvider(arg).notifier)
          .loadHistoryMessages(count: 20, startClientMsgId: startClientMsgId);
      final loadError = ref.read(messageListProvider(arg)).error;
      state = state.copyWith(
        isLoading: false,
        hasMoreHistory: loadError == null ? hasMore : state.hasMoreHistory,
        errorText: loadError,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorText: '加载历史消息失败: $e');
    }
  }

  Future<void> markConversationMessageAsRead() async {
    final conv = conversation;
    if (conv == null || conv.unreadCount <= 0) return;

    final now = DateTime.now();
    if (_lastMarkReadTime != null &&
        now.difference(_lastMarkReadTime!).inMilliseconds < 1000) {
      return;
    }
    _lastMarkReadTime = now;

    try {
      await _messageService.markConversationMessageAsRead(arg);
    } catch (e) {
      state = state.copyWith(errorText: '标记已读失败: $e');
    }
  }

  Future<void> saveDraft(String text) async {
    if (text.isNotEmpty) {
      await _messageService.saveDraft(arg, jsonEncode({'text': text}));
    } else {
      await _messageService.clearDraft(arg);
    }
  }

  void sendTyping({required bool focus}) {
    final target = sendTarget;
    if (target == null) return;
    unawaited(
      _messageService.sendTyping(
        sourceId: target.recvId,
        sessionType: target.sessionType,
        focus: focus,
      ),
    );
  }

  void onTextChanged() {
    final now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!).inSeconds < 3) {
      return;
    }
    _lastTypingSent = now;
    sendTyping(focus: true);
  }

  Future<void> subscribeOnlineStatus() async {
    final conv = conversation;
    if (conv == null || conv.conversationType != 1) return;
    final userId = conv.userId.isNotEmpty ? conv.userId : null;
    if (userId == null) return;
    _onlineStatusUserId = userId;
    await ref.read(chatAuxRepositoryProvider).subscribeOnlineStatus([userId]);
  }

  Future<void> unsubscribeOnlineStatus() async {
    final userId = _onlineStatusUserId;
    _onlineStatusUserId = null;
    if (userId == null) return;
    await ref.read(chatAuxRepositoryProvider).unsubscribeOnlineStatus([userId]);
  }

  Future<bool> sendText(String text, MessageContentType type) async {
    if (text.trim().isEmpty) return false;
    if (!ref.read(connectionProvider).isConnected) {
      state = state.copyWith(errorText: 'WebSocket 未连接，无法发送消息');
      return false;
    }
    final target = sendTarget;
    if (target == null) {
      state = state.copyWith(errorText: '无法发送：会话缺少对方 ID，请返回会话列表重试');
      return false;
    }

    try {
      final quotedMsg = state.quotedMessage;
      final atUserIds = List<String>.from(state.atUserIds);
      if (atUserIds.isNotEmpty) {
        state = state.copyWith(atUserIds: const []);
        await ref
            .read(messageListProvider(arg).notifier)
            .sendAtTextMessage(
              recvId: target.recvId,
              text: text,
              atUserIds: atUserIds,
              sessionType: target.sessionType,
              groupId: target.groupId,
            );
      } else if (quotedMsg != null) {
        state = state.copyWith(clearQuotedMessage: true);
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
            .read(messageListProvider(arg).notifier)
            .sendMarkdownMessage(
              recvId: target.recvId,
              text: text,
              sessionType: target.sessionType,
              groupId: target.groupId,
            );
      } else {
        await ref
            .read(messageListProvider(arg).notifier)
            .sendTextMessage(
              recvId: target.recvId,
              text: text,
              sessionType: target.sessionType,
              groupId: target.groupId,
            );
      }
      state = state.copyWith(clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(errorText: '发送消息失败: $e');
      return false;
    }
  }

  Future<bool> sendImage(String filePath) => _sendMedia(
    (target) => ref
        .read(messageListProvider(arg).notifier)
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
        .read(messageListProvider(arg).notifier)
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
        .read(messageListProvider(arg).notifier)
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
        .read(messageListProvider(arg).notifier)
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
        .read(messageListProvider(arg).notifier)
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
        .read(messageListProvider(arg).notifier)
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
    final target = sendTarget;
    if (target == null) {
      state = state.copyWith(errorText: '会话信息异常');
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
      state = state.copyWith(errorText: '发送名片失败: $e');
      return false;
    }
  }

  Future<List<Friend>> loadFriendsForPicker() async {
    final state = ref.read(friendListProvider);
    if (state.friends.isEmpty && !state.isLoading) {
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
      state = state.copyWith(errorText: '打开文件失败: $e');
      return false;
    }
  }

  Future<bool> _sendMedia(
    Future<bool> Function(ChatSendTarget target) send,
  ) async {
    final target = sendTarget;
    if (target == null) {
      state = state.copyWith(errorText: '会话信息异常');
      return false;
    }
    final ok = await send(target);
    if (!ok) {
      final error = ref.read(messageListProvider(arg)).error;
      state = state.copyWith(errorText: error ?? '发送失败');
    }
    return ok;
  }

  void setQuotedMessage(ChatMessage message) {
    state = state.copyWith(quotedMessage: message);
  }

  void clearQuotedMessage() {
    state = state.copyWith(clearQuotedMessage: true);
  }

  void addAtUserId(String userId) {
    if (state.atUserIds.contains(userId)) return;
    state = state.copyWith(atUserIds: [...state.atUserIds, userId]);
  }

  void clearAtUserIds() {
    state = state.copyWith(atUserIds: const []);
  }

  Future<bool> revokeMessage(ChatMessage message) async {
    final conv = conversation;
    if (conv == null) return false;
    try {
      await _messageService.revokeMessage(
        conversationId: conv.conversationId,
        seq: message.seq.toInt(),
        clientMsgId: message.clientMsgId,
        sessionType: conv.conversationType,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorText: '撤回失败: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(ChatMessage message) async {
    try {
      await _messageService.deleteMessage(
        conversationId: arg,
        clientMsgId: message.clientMsgId,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorText: '删除失败: $e');
      return false;
    }
  }

  Future<bool> resendMessage(ChatMessage message) async {
    final target = sendTarget;
    if (target == null) {
      state = state.copyWith(errorText: '会话信息异常，无法重发');
      return false;
    }
    final sourceId = target.groupId.isNotEmpty ? target.groupId : target.recvId;
    final ok = await ref
        .read(messageListProvider(arg).notifier)
        .resendMessage(
          message: message,
          sourceId: sourceId,
          sessionType: target.sessionType,
        );
    if (!ok) {
      state = state.copyWith(
        errorText: ref.read(messageListProvider(arg)).error ?? '消息重发失败',
      );
    }
    return ok;
  }

  Future<List<MessageSearchResult>> searchLocalMessages(String keyword) {
    return _messageService.searchLocalMessages(
      conversationId: arg,
      keyword: keyword,
    );
  }

  void reset() {
    state = const ChatDetailState();
  }
}
