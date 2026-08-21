import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../providers/online_status_provider.dart';
import '../../../router/app_router.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../contacts/views/contact_picker_screen.dart';
import '../../contacts/widgets/contact_pick_item.dart';
import '../../groups/providers/group_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../profile/view_models/user_profile_view_model.dart';
import '../providers/chat_detail_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/message_provider.dart';
import '../providers/message_service_provider.dart';
import '../view_models/chat_detail_view_model.dart';
import '../widgets/composer/chat_input.dart' show ChatInput;
import '../widgets/message_content_type.dart' show MessageContentType;
import '../widgets/menu/chat_media_actions.dart';
import '../widgets/menu/chat_message_actions.dart';
import '../widgets/menu/chat_detail_selection_top_bar.dart';
import '../widgets/chat_message_search_sheet.dart';
import '../widgets/menu/message_action_menu.dart';
import '../widgets/composer/group_member_picker.dart'
    show insertAtMention, showGroupMemberPicker;
import '../widgets/menu/message_hover_toolbar.dart' show MessageReactionGroup;
import '../widgets/list/chat_message_list_section.dart';
import '../widgets/list/forward_progress_banner.dart';
import '../widgets/list/message_list.dart';
import '../widgets/composer/quote_preview_bar.dart';
import '../widgets/shared/chat_detail_app_bar.dart';

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
  final Map<String, List<MessageReactionGroup>> _messageReactions = {};
  final Set<String> _pinnedMessageIds = {};
  ChatDetailViewModel? _viewModel;
  late final ChatMediaActions _mediaActions;
  late final ChatMessageActions _messageActions;

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
    _messageActions = ChatMessageActions(
      viewModel: _viewModel!,
      preLoaded: widget.preLoaded,
      readState: () => _chatState,
      messageReactions: _messageReactions,
      pinnedMessageIds: _pinnedMessageIds,
      onError: _showError,
      onClearComposer: () => _textController.clear(),
      onScrollToBottom: _scrollToBottom,
      onStateChanged: () => setState(() {}),
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
    final messages = ref.read(
      messagesByConversationProvider(widget.conversationId),
    );
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

  /// 群成员列表（实时 @ 用，仅群聊；成员未加载时为空，实时 @ 不激活，可走工具栏 @ 按钮）
  List<GroupMember> get _atMembers {
    if (!_isGroup) return const [];
    final target = _viewModel?.sendTarget;
    if (target == null || target.groupId.isEmpty) return const [];
    return ref.read(groupMemberProvider(target.groupId)).members;
  }

  Future<void> _sendGif(String url) async {
    final ok = await _viewModel?.sendGif(url) ?? false;
    if (!ok) _showError('发送 GIF 失败');
  }

  void _onAtMemberSelected(String userId) {
    _viewModel?.addAtUserId(userId);
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

  Future<void> _sendMessage(String text, MessageContentType type) =>
      _messageActions.sendText(text, type);

  Future<void> _showAtMentionPicker() async {
    final target = _viewModel?.sendTarget;
    if (target == null) return;

    if (!_isGroup) {
      final items = await Navigator.of(context).push<List<ContactPickItem>>(
        MaterialPageRoute(
          builder: (_) =>
              const ContactPickerScreen(title: '@ 选择联系人', includeGroups: false),
        ),
      );
      if (items == null || items.isEmpty || !mounted) return;
      final selected = items.first;
      _insertAtMention(selected.name, selected.id);
      return;
    }

    if (target.groupId.isEmpty) return;

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

    final selected = await showGroupMemberPicker(context, members);

    if (selected == null || !mounted) return;
    final displayName = selected.nickname.isNotEmpty
        ? selected.nickname
        : selected.userId;
    _insertAtMention(displayName, selected.userId);
  }

  void _insertAtMention(String displayName, String userId) {
    insertAtMention(_textController, displayName, userId);
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

  void _locateMessage(MessageSearchResult log) {
    final messages = ref.read(
      messagesByConversationProvider(widget.conversationId),
    );
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

  Future<void> _pickImages() => _mediaActions.pickImages(context);

  Future<void> _pickFromCamera() => _mediaActions.pickFromCamera(context);

  Future<void> _pickLocation() => _mediaActions.pickLocation(context);

  Future<void> _pickFile() => _mediaActions.pickFile(context);

  Future<void> _pickVideo() => _mediaActions.pickVideo(context);

  Future<void> _sendVoiceMessage(int duration, String filePath) =>
      _mediaActions.sendVoiceMessage(duration, filePath);

  Future<void> _sendCardMessage() => _mediaActions.sendCardMessage(context);

  MessageActions _buildMessageActions(ChatMessage msg) {
    return MessageActions(
      onCopy: (message) => _messageActions.copy(message, context),
      onRevoke: _messageActions.revoke,
      onDelete: _messageActions.delete,
      onForward: (message) => _messageActions.forward(message, context),
      onQuote: (message) => _viewModel?.setQuotedMessage(message),
      onMultiSelect: () => _viewModel?.enterSelectMode(),
      onResend: _messageActions.resend,
      onPin: (message) => _messageActions.togglePin(message, context),
      onReaction: _messageActions.toggleReaction,
      onQuickReply: _messageActions.sendQuickReply,
    );
  }

  void _handleMessageTap(ChatMessage msg) =>
      _messageActions.handleTap(msg, context);

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
        appBar: ChatDetailAppBar(
          user: user,
          unread: unread,
          isTyping: isTyping,
          isGroup: _isGroup,
          online: online,
          onBack: () {
            _onUserGoBack();
            Navigator.of(context).pop();
          },
          onOpenSettings: () {
            AppRouter.goToChatSettings(context, conversation);
          },
          onSearch: _showMessageSearch,
        ),
        body: _bodyReady
            ? Column(
                children: [
                  if (chatDetailState.selectMode)
                    ChatDetailSelectionTopBar(
                      conversationId: widget.conversationId,
                      selectedCount: chatDetailState.selectedMessages.length,
                      onSelectAll: () => _viewModel?.toggleSelectAll(),
                      onClose: () => _viewModel?.exitSelectMode(),
                      onDelete: () => _messageActions.deleteSelected(context),
                      onForwardOneByOne: () => _messageActions.forwardSelected(
                        context,
                        merge: false,
                      ),
                      onMergeForward: () =>
                          _messageActions.forwardSelected(context, merge: true),
                    ),
                  Expanded(
                    child: ChatMessageListSection(
                      conversationId: widget.conversationId,
                      user: user,
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
                      messageReactions: _messageReactions,
                      onMessageVisible: (msg) {
                        if (!msg.isRead &&
                            msg.sendId !=
                                (currentUserId.isNotEmpty
                                    ? currentUserId
                                    : null)) {
                          _viewModel?.markConversationMessageAsRead();
                        }
                      },
                      messageActionsBuilder: _buildMessageActions,
                      onMessageTap: _handleMessageTap,
                    ),
                  ),
                  if (chatDetailState.isForwarding)
                    ForwardProgressBanner(
                      done: chatDetailState.forwardDone,
                      total: chatDetailState.forwardTotal,
                      onCancel: () => _viewModel?.cancelForward(),
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
                    onImagesPick: _pickImages,
                    onCameraPick: _pickFromCamera,
                    onLocationPick: _pickLocation,
                    onFilePick: _pickFile,
                    onVideoPick: _pickVideo,
                    onCardSend: _sendCardMessage,
                    onVoiceRecord: _sendVoiceMessage,
                    onAtMention: _showAtMentionPicker,
                    onGifSelected: _sendGif,
                    atMembers: _atMembers,
                    onAtMemberSelected: _onAtMemberSelected,
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
