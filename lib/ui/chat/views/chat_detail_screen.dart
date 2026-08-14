import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/message.dart' show MessageType;
import '../../../domain/extensions/message_ext.dart';
import '../../../domain/models/user.dart';
import '../../../generated/rust/model/group.dart' show GroupMember;
import '../../../generated/rust/model/local.dart' show LocalChatLog;
import '../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../providers/online_status_provider.dart';
import '../../../router/app_router.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';
import '../../contacts/widgets/contact_pick_item.dart';
import '../../groups/providers/group_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../profile/view_models/user_profile_view_model.dart';
import '../providers/chat_detail_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/message_provider.dart';
import '../providers/message_service_provider.dart';
import '../view_models/chat_detail_view_model.dart';
import '../widgets/chat_input.dart' show ChatInput, MessageContentType;
import '../widgets/chat_media_actions.dart';
import '../widgets/chat_message_search_sheet.dart';
import '../widgets/media_viewer.dart';
import '../widgets/message_action_menu.dart';
import '../widgets/message_list.dart';
import '../widgets/message_selection_bar.dart';
import '../widgets/quote_preview_bar.dart';

/// 聊天详情页：顶栏、消息区、底部输入区。
/// 业务状态由 [ChatDetailViewModel] 管理，页面只保留布局、滚动、选择器与导航。
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final bool preLoaded;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.preLoaded = false,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<MessageListState> _messageListKey =
      GlobalKey<MessageListState>();
  bool _bodyReady = false;
  String _lastMessageListTailId = '';
  ChatDetailViewModel? _viewModel;
  late final ChatMediaActions _mediaActions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = ref.read(
      chatDetailViewModelProvider(widget.conversationId).notifier,
    );
    _mediaActions = ChatMediaActions(
      viewModel: _viewModel!,
      onError: _showError,
      onScrollToBottom: _scrollToBottom,
      preLoaded: widget.preLoaded,
    );
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
    ref.listenManual(
      messageListProvider(widget.conversationId),
      (_, __) => _onMessageListChanged(),
    );
    _onMessageListChanged();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = _viewModel;
      if (viewModel == null) return;
      ref.read(selectedConversationIdProvider.notifier).state =
          widget.conversationId;
      if (!widget.preLoaded) {
        unawaited(viewModel.loadMessages());
      }
      if (mounted) setState(() => _bodyReady = true);
      unawaited(viewModel.markConversationMessageAsRead());
      _restoreDraft(viewModel);
      unawaited(viewModel.subscribeOnlineStatus());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final viewModel = _viewModel;
    if (viewModel != null) {
      unawaited(viewModel.unsubscribeOnlineStatus());
      unawaited(viewModel.saveDraft(_textController.text));
    }
    _scrollController.removeListener(_onScroll);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _restoreDraft(ChatDetailViewModel viewModel) {
    final draftText = viewModel.draftText;
    if (draftText == null || draftText.isEmpty) return;
    _textController.text = draftText;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: draftText.length),
    );
  }

  void _onTextChanged() {
    _viewModel?.onTextChanged();
  }

  void _onMessageListChanged() {
    final messages = ref
        .read(messageListProvider(widget.conversationId))
        .messages;
    if (messages.isEmpty) {
      _lastMessageListTailId = '';
      return;
    }
    final last = messages.last;
    final lastId = last.clientMsgId;
    if (lastId == _lastMessageListTailId) return;
    _lastMessageListTailId = lastId;
    final isOwnMessage = _viewModel?.currentUserId == last.sendId;
    if (!isOwnMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
  }

  void _onScroll() {
    final state = _chatState;
    if (state.isLoading || !state.hasMoreHistory) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      unawaited(_viewModel!.loadMessages(isLoadMore: true));
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels != 0) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onUserGoBack() {
    _viewModel?.saveDraft(_textController.text);
    _viewModel?.markConversationMessageAsRead();
  }

  ChatDetailState get _chatState =>
      ref.read(chatDetailViewModelProvider(widget.conversationId));

  Conversation? get _conversation {
    final conversations = ref.read(conversationListProvider).conversations;
    try {
      return conversations.firstWhere(
        (c) => c.conversationId == widget.conversationId,
      );
    } catch (_) {
      return null;
    }
  }

  bool get _isGroup {
    final conversation = _conversation;
    return conversation?.conversationType == 2 ||
        conversation?.conversationType == 3;
  }

  User _getUser(UserProfileState userProfileState) {
    final conversation = _conversation;
    if (conversation == null) {
      return User(
        id: widget.conversationId,
        name: '未知会话',
        avatar: null,
        status: null,
      );
    }

    final userId = conversation.userId.isNotEmpty
        ? conversation.userId
        : conversation.groupId;
    final userName = conversation.showName.isNotEmpty
        ? conversation.showName
        : conversation.conversationId;
    final cached = conversation.userId.isNotEmpty
        ? ref
              .read(userProfileProvider.notifier)
              .getUserProfile(conversation.userId)
        : null;

    return User(
      id: userId,
      name: (cached?.nickname ?? '').isNotEmpty ? cached!.nickname : userName,
      avatar: (cached?.faceUrl ?? '').isNotEmpty
          ? cached!.faceUrl
          : conversation.faceUrl.isNotEmpty
          ? conversation.faceUrl
          : null,
      status: null,
    );
  }

  Future<void> _sendMessage(String text, MessageContentType type) async {
    final ok = await _viewModel?.sendText(text, type) ?? false;
    if (ok) {
      _textController.clear();
      if (!widget.preLoaded) _scrollToBottom();
    } else {
      _showError(_chatState.errorText ?? '发送消息失败');
    }
  }

  Future<void> _showAtMentionPicker() async {
    final target = _viewModel?.sendTarget;
    if (target == null || target.groupId.isEmpty) return;

    final memberState = ref.read(groupMemberProvider(target.groupId));
    if (memberState.members.isEmpty) {
      await ref
          .read(groupMemberProvider(target.groupId).notifier)
          .loadMembers();
      if (!mounted) return;
    }
    final members = ref.read(groupMemberProvider(target.groupId)).members;
    if (members.isEmpty) {
      _showError('暂无可选群成员');
      return;
    }

    final selected = await showModalBottomSheet<GroupMember>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '@ 选择群成员',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final member = members[i];
                  return ListTile(
                    leading: UserAvatar(
                      user: User(
                        id: member.userId,
                        name: member.nickname,
                        avatar: member.faceUrl.isNotEmpty
                            ? member.faceUrl
                            : null,
                      ),
                      radius: 18,
                    ),
                    title: Text(
                      member.nickname.isNotEmpty
                          ? member.nickname
                          : member.userId,
                    ),
                    onTap: () => Navigator.of(ctx).pop(member),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final text = _textController.text;
    final suffix = text.isEmpty || text.endsWith(' ') ? '' : ' ';
    final displayName = selected.nickname.isNotEmpty
        ? selected.nickname
        : selected.userId;
    final inserted = '$text$suffix@$displayName ';
    _textController.value = TextEditingValue(
      text: inserted,
      selection: TextSelection.collapsed(offset: inserted.length),
    );
    _viewModel?.addAtUserId(selected.userId);
  }

  void _showMessageSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChatMessageSearchSheet(
        conversationId: widget.conversationId,
        onMessageTap: _locateMessage,
      ),
    );
  }

  void _locateMessage(LocalChatLog log) {
    final messages = ref
        .read(messageListProvider(widget.conversationId))
        .messages;
    final index = messages.indexWhere(
      (m) =>
          m.clientMsgId == log.clientMsgId ||
          (m.seq.toInt() == log.seq.toInt() && m.sendId == log.sendId),
    );
    if (index < 0) {
      _showError('未找到对应消息');
      return;
    }
    final message = messages[index];
    _messageListKey.currentState?.scrollToMessage(message.clientMsgId);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.appColors.danger),
    );
  }

  Future<void> _pickImage() => _mediaActions.pickImage(context);

  Future<void> _pickFromCamera() => _mediaActions.pickFromCamera(context);

  Future<void> _pickLocation() => _mediaActions.pickLocation(context);

  Future<void> _pickFile() => _mediaActions.pickFile(context);

  Future<void> _pickVideo() => _mediaActions.pickVideo(context);

  Future<void> _sendVoiceMessage(int duration, String filePath) =>
      _mediaActions.sendVoiceMessage(duration, filePath);

  Future<void> _sendCardMessage() => _mediaActions.sendCardMessage(context);

  Future<void> _revokeMessage(dynamic msg) async {
    final ok = await _viewModel?.revokeMessage(msg as MessageInfo) ?? false;
    if (!ok) _showError(_chatState.errorText ?? '撤回失败');
  }

  Future<void> _deleteMessage(dynamic msg) async {
    final ok = await _viewModel?.deleteMessage(msg as MessageInfo) ?? false;
    if (!ok) _showError(_chatState.errorText ?? '删除失败');
  }

  Future<void> _resendMessage(MessageInfo msg) async {
    final ok = await _viewModel?.resendMessage(msg) ?? false;
    if (!ok) _showError(_chatState.errorText ?? '消息重发失败');
  }

  void _handleMessageTap(MessageInfo msg) {
    final state = _chatState;
    if (state.selectMode) {
      _viewModel?.toggleMessageSelection(msg);
      return;
    }
    switch (msg.messageType) {
      case MessageType.merge:
        AppRouter.goToMergeMessage(context, msg);
      case MessageType.image:
        final source = msg.displayImageSource;
        if (source.isNotEmpty) {
          openImagePreview(
            context,
            source: source,
            suggestedName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      case MessageType.video:
        openVideoPreview(context, source: msg.videoSource);
      case MessageType.file:
        _showFileActions(msg);
      case MessageType.card:
        if (msg.cardUserId.isNotEmpty) {
          AppRouter.goToUserProfile(
            context,
            userId: msg.cardUserId,
            user: User(
              id: msg.cardUserId,
              name: msg.cardNickname.isNotEmpty
                  ? msg.cardNickname
                  : msg.cardUserId,
              avatar: msg.cardFaceUrl.isNotEmpty ? msg.cardFaceUrl : null,
            ),
          );
        }
      case MessageType.location:
        _showLocationDetail(msg);
      case MessageType.custom:
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('自定义消息'),
            content: SelectableText(msg.displayText),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      default:
        break;
    }
  }

  Future<void> _showFileActions(MessageInfo msg) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('打开文件'),
              onTap: () => Navigator.of(sheetContext).pop('open'),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('保存/另存为'),
              onTap: () => Navigator.of(sheetContext).pop('save'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final source = msg.fileSource;
    final name = msg.fileName.isNotEmpty
        ? msg.fileName
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    if (action == 'save') {
      await saveMessageMedia(context, source: source, suggestedName: name);
      return;
    }

    if (source.isEmpty) {
      _showError('文件地址为空，无法打开');
      return;
    }
    try {
      final ok =
          await _viewModel?.openFile(source: source, fileName: name) ?? false;
      if (!ok && mounted) {
        _showError('没有可打开该文件的应用，可尝试保存后打开');
      }
    } catch (e) {
      _showError('打开文件失败: $e');
    }
  }

  void _showLocationDetail(MessageInfo msg) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(msg.locationName.isNotEmpty ? msg.locationName : '位置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.locationDesc.isNotEmpty) ...[
              Text(msg.locationDesc),
              const SizedBox(height: 8),
            ],
            Text(
              '纬度: ${msg.latitude.toStringAsFixed(6)}\n'
              '经度: ${msg.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardSelected({required bool merge}) async {
    final selected = ref
        .read(chatDetailViewModelProvider(widget.conversationId))
        .selectedMessages;
    if (selected.isEmpty) return;
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '选择转发目标',
    );
    if (result == null || result.isEmpty || !mounted) return;
    final target = result.first;
    final ok =
        await _viewModel?.forwardSelectedMessages(
          messages: selected,
          targetId: target.id,
          isGroup: target.isGroup,
          merge: merge,
        ) ??
        false;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已转发 ${selected.length} 条消息给 ${target.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      _showError(_chatState.errorText ?? '转发失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(
      chatDetailViewModelProvider(widget.conversationId),
    );
    final userProfileState = ref.watch(userProfileProvider);
    final unread = ref.watch(
      conversationListProvider.select(
        (state) =>
            state.conversations
                .where((c) => c.conversationId == widget.conversationId)
                .firstOrNull
                ?.unreadCount ??
            0,
      ),
    );
    final user = _getUser(userProfileState);
    final conversation = _conversation;
    final otherUserId = conversation?.conversationType == 1
        ? conversation!.userId
        : '';
    final online = otherUserId.isNotEmpty
        ? ref.watch(userOnlineStatusProvider(otherUserId))
        : null;
    final currentUserId =
        _viewModel?.currentUserId ?? userProfileState.profile?.userId ?? '';
    final typingUserId = ref.watch(
      messageServiceProvider.select(
        (s) => s.typingUsers[widget.conversationId],
      ),
    );
    final isTyping =
        typingUserId != null &&
        typingUserId.isNotEmpty &&
        typingUserId != currentUserId;

    if (conversation == null) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('会话不存在'),
        ),
        body: const Center(child: Text('会话信息不存在或已被删除')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onUserGoBack();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.arrow_back_ios_new, size: 22),
                if (unread > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.danger,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: TextStyle(
                          color: context.appColors.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              _onUserGoBack();
              Navigator.of(context).pop();
            },
          ),
          title: LayoutBuilder(
            builder: (context, constraints) {
              return InkWell(
                onTap: () {
                  AppRouter.goToChatSettings(context, conversation);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(user: user, radius: 18),
                    const SizedBox(width: 10),
                    SizedBox(
                      width:
                          constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 56
                          ? constraints.maxWidth - 56
                          : 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.textPrimary,
                            ),
                          ),
                          if (isTyping)
                            Text(
                              '对方正在输入...',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.primary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            )
                          else if (_isGroup)
                            Text(
                              '群聊',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.textSecondary
                                    .withValues(alpha: 0.9),
                              ),
                            )
                          else
                            Text(
                              switch (online) {
                                true => '在线',
                                false => '离线',
                                null => '未知',
                              },
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.textSecondary
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            Semantics(
              label: '搜索聊天记录',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.search),
                tooltip: '搜索聊天记录',
                onPressed: _showMessageSearch,
              ),
            ),
            Semantics(
              label: '更多设置',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: '更多设置',
                onPressed: () {
                  AppRouter.goToChatSettings(context, conversation);
                },
              ),
            ),
          ],
        ),
        body: _bodyReady
            ? Column(
                children: [
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => FocusScope.of(context).unfocus(),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final messageState = ref.watch(
                            messageListProvider(widget.conversationId),
                          );
                          final messages = messageState.messages;

                          return MessageList(
                            key: _messageListKey,
                            messages: messages,
                            otherUser: user,
                            currentUserId: currentUserId.isNotEmpty
                                ? currentUserId
                                : null,
                            currentUserAvatar: ref
                                .read(userProfileProvider.notifier)
                                .getDisplayAvatarUrl(),
                            scrollController: _scrollController,
                            isLoading: chatDetailState.isLoading,
                            selectMode: chatDetailState.selectMode,
                            selectedClientMsgIds:
                                chatDetailState.selectedClientMsgIds,
                            uploadProgress: ref.watch(
                              messageServiceProvider.select(
                                (s) => s.uploadProgress,
                              ),
                            ),
                            groupReadReceipts: ref.watch(
                              messageServiceProvider.select(
                                (s) => s.groupReadReceipts,
                              ),
                            ),
                            cachedCurrentUserProfile: ref.watch(
                              messageServiceProvider.select(
                                (s) => s.loginUserProfile,
                              ),
                            ),
                            onMessageVisible: (msg) {
                              if (!msg.isRead &&
                                  msg.sendId !=
                                      (currentUserId.isNotEmpty
                                          ? currentUserId
                                          : null)) {
                                _viewModel?.markConversationMessageAsRead();
                              }
                            },
                            onMessageLongPress: (msg) => showMessageActionMenu(
                              context,
                              message: msg,
                              currentUserId: currentUserId,
                              actions: MessageActions(
                                onCopy: (_) {},
                                onRevoke: _revokeMessage,
                                onDelete: _deleteMessage,
                                onForward: (msg) async {
                                  final result =
                                      await AppRouter.goToContactPicker<
                                        List<ContactPickItem>
                                      >(context, title: '转发给');
                                  if (result != null && result.isNotEmpty) {
                                    final target = result.first;
                                    final ok =
                                        await _viewModel
                                            ?.forwardSelectedMessages(
                                              messages: [msg],
                                              targetId: target.id,
                                              isGroup: target.isGroup,
                                              merge: false,
                                            ) ??
                                        false;
                                    if (ok && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('已转发给 ${target.name}'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                onQuote: (msg) =>
                                    _viewModel?.setQuotedMessage(msg),
                                onMultiSelect: () =>
                                    _viewModel?.enterSelectMode(),
                                onResend: _resendMessage,
                              ),
                            ),
                            onMessageTap: _handleMessageTap,
                          );
                        },
                      ),
                    ),
                  ),
                  if (chatDetailState.selectMode)
                    MessageSelectionBar(
                      count: chatDetailState.selectedMessages.length,
                      onForwardOneByOne: () => _forwardSelected(merge: false),
                      onMergeForward: () => _forwardSelected(merge: true),
                      onClose: () => _viewModel?.exitSelectMode(),
                    ),
                  if (chatDetailState.quotedMessage != null)
                    QuotePreviewBar(
                      message: chatDetailState.quotedMessage!,
                      onClose: () => _viewModel?.clearQuotedMessage(),
                    ),
                  ChatInput(
                    controller: _textController,
                    onSend: _sendMessage,
                    onImagePick: _pickImage,
                    onCameraPick: _pickFromCamera,
                    onLocationPick: _pickLocation,
                    onFilePick: _pickFile,
                    onVideoPick: _pickVideo,
                    onCardSend: _sendCardMessage,
                    onVoiceRecord: _sendVoiceMessage,
                    onAtMention: _showAtMentionPicker,
                    isGroupChat: _isGroup,
                  ),
                ],
              )
            : ColoredBox(
                color: context.appColors.background,
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}
