import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../providers/im_providers.dart';
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
import '../mappers/message_media.dart';
import '../widgets/list/message_list.dart';
import '../widgets/composer/quote_preview_bar.dart';
import '../widgets/shared/chat_detail_app_bar.dart';

/// 聊天详情页：顶栏、消息区、底部输入区。
/// 业务状态由 [ChatDetailViewModel] 管理，页面只保留布局、滚动、选择器与导航。
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final bool preLoaded;

  /// 从会话列表「@我」筛选进入时，加载后定位到第一条提及我的消息。
  final bool focusAtMe;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.preLoaded = false,
    this.focusAtMe = false,
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

  /// 输入行 + 已展开面板的总高度（由 ChatInput 实测上报）。
  ///
  /// 用 ValueNotifier 而不是 setState：高度变化只影响「输入区上浮距离」与
  /// 「消息列表底部预留」两处，不必重建整页。
  final ValueNotifier<double> _inputAreaHeight = ValueNotifier<double>(0);
  bool _bodyReady = false;

  /// 入场转场结束后要执行的副作用（见 [_afterRouteTransition]）。
  VoidCallback? _pendingAfterTransition;
  Animation<double>? _routeTransitionAnimation;
  String _lastMessageListTailId = '';
  String? _lastReportedSendError;
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
      imagePickerService: ref.read(imagePickerServiceProvider),
      mediaImportService: ref.read(mediaImportServiceProvider),
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
      _restoreDraft(viewModel);
      _sweepStaleSending();
      // 标记已读 / 订阅在线状态的 RPC 回包会改写会话、未读与在线状态，
      // 进而触发本页（以及栈里仍挂载的会话列表）重建。放到入场转场结束后再发，
      // 避免与首帧渲染抢 UI 线程；两者都不影响消息内容的首屏展示。
      _afterRouteTransition(() {
        unawaited(viewModel.markConversationMessageAsRead());
        unawaited(viewModel.subscribeOnlineStatus());
      });
    });
  }

  /// 入场转场结束后执行，避免转场期间触发额外重建。
  ///
  /// 早先这里用「等 400ms」猜转场时长：猜短了会撞上转场、猜长了白等。
  /// 现在直接监听本页路由的转场动画，转场一结束就执行（没有转场则立即执行）。
  void _afterRouteTransition(VoidCallback action) {
    _pendingAfterTransition = action;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _runAfterTransition();
      return;
    }
    // 用可移除的状态回调：页面提前销毁时不留悬挂回调（也避免 widget 测试残留 pending timer）
    _routeTransitionAnimation?.removeStatusListener(_onRouteTransitionStatus);
    _routeTransitionAnimation = animation
      ..addStatusListener(_onRouteTransitionStatus);
  }

  void _onRouteTransitionStatus(AnimationStatus status) {
    // 只认「转场结束」：转场中途退出（status 变 dismissed）不该再发 RPC
    if (status == AnimationStatus.completed) _runAfterTransition();
  }

  void _runAfterTransition() {
    final action = _pendingAfterTransition;
    _pendingAfterTransition = null;
    _routeTransitionAnimation?.removeStatusListener(_onRouteTransitionStatus);
    _routeTransitionAnimation = null;
    if (action == null || !mounted) return;
    action();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeTransitionAnimation?.removeStatusListener(_onRouteTransitionStatus);
    _routeTransitionAnimation = null;
    _pendingAfterTransition = null;
    final viewModel = _viewModel;
    if (viewModel != null) {
      // 退出会话：结束「正在输入」，避免对端提示挂住
      viewModel.stopTyping();
      unawaited(viewModel.unsubscribeOnlineStatus());
      unawaited(viewModel.saveDraft(_textController.text));
      // 退出会话补一次已读：系统返回键不再被 PopScope 拦截，退出路径统一收口到 dispose
      unawaited(viewModel.markConversationMessageAsRead());
    }
    _scrollController.removeListener(_onScroll);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _inputAreaHeight.dispose();
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
    _viewModel?.onTextChanged(text: _textController.text);
  }

  /// 回前台时补一次僵尸发送兜底（后台期间网络中断的消息不会收到回执）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sweepStaleSending();
  }

  /// 把长时间停在「发送中」的消息标为失败，让用户可以直接重发
  void _sweepStaleSending() => ref
      .read(messageServiceProvider.notifier)
      .sweepStaleSendingMessages(widget.conversationId);

  bool _focusAtMeHandled = false;

  void _onMessageListChanged() {
    _reportSendError();
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
    _maybeJumpToAtMe();
  }

  /// 发送失败是「本地先上屏、结果异步返回」，失败原因落在消息列表状态上，
  /// 这里统一转成一次性提示（同一错误只提示一次）。
  void _reportSendError() {
    final error = ref.read(messageListProvider(widget.conversationId)).error;
    if (error == null || error == _lastReportedSendError) return;
    _lastReportedSendError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showError(error);
    });
  }

  /// 从「@我」筛选进入时，定位到第一条提及当前用户的消息。
  void _maybeJumpToAtMe() {
    if (!widget.focusAtMe || _focusAtMeHandled) return;
    final messages = ref.read(
      messagesByConversationProvider(widget.conversationId),
    );
    if (messages.isEmpty) return;
    _focusAtMeHandled = true;
    final currentUserId = _viewModel?.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;
    ChatMessage? target;
    for (final message in messages) {
      if (message.atUserIds.contains(currentUserId)) {
        target = message;
        break;
      }
    }
    if (target == null) {
      _showError('未找到提及你的消息');
      return;
    }
    final targetId = target.clientMsgId;
    // 等底部自动滚动结束后再定位，避免被覆盖。
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _messageListKey.currentState?.scrollToMessage(targetId);
    });
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

  /// 当前会话：复用 conversationByIdProvider 的结果（会话列表变化时才重算），
  /// 避免在 build 内多次全表扫描会话列表。
  Conversation? get _conversation =>
      ref.read(conversationByIdProvider(widget.conversationId));

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
    );
  }

  void _handleMessageTap(ChatMessage msg) =>
      _messageActions.handleTap(msg, context);

  Widget _buildMissingConversation() {
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

  Widget _buildMessageListSection(
    ChatDetailState chatDetailState,
    User user,
    String currentUserId,
  ) {
    return Expanded(
      // 业界模型：列表留白 = 「输入行 + 底部占位块」，占位块 = max(面板, 键盘)。
      // 键盘占多少就让多少，最新消息始终停在输入行上方；面板与键盘等高时
      // 留白恒定，两者互相切换时列表零位移。
      // 直接跟随 inset 逐帧变化（不做自绘补间），避免与系统键盘动画错拍。
      child: ValueListenableBuilder<double>(
        valueListenable: _inputAreaHeight,
        builder: (context, inputInset, child) => Padding(
          padding: EdgeInsets.only(bottom: inputInset),
          child: child,
        ),
        // RepaintBoundary 隔离消息列表重绘：列表视口变化时只重绘列表图层，
        // 避免影响顶栏/输入区等其他区域。用 child 传入避免每次高度变化都重建列表。
        child: RepaintBoundary(
          child: ChatMessageListSection(
            conversationId: widget.conversationId,
            user: user,
            currentUserId: currentUserId.isNotEmpty ? currentUserId : null,
            currentUserAvatar: ref
                .read(userProfileProvider.notifier)
                .getDisplayAvatarUrl(),
            scrollController: _scrollController,
            isLoading: chatDetailState.isLoading,
            selectMode: chatDetailState.selectMode,
            selectedClientMsgIds: chatDetailState.selectedClientMsgIds,
            messageReactions: _messageReactions,
            onMessageVisible: (msg) {
              if (!msg.isRead &&
                  msg.sendId !=
                      (currentUserId.isNotEmpty ? currentUserId : null)) {
                _viewModel?.markConversationMessageAsRead();
              }
            },
            messageActionsBuilder: _buildMessageActions,
            onMessageTap: _handleMessageTap,
            // 点失败标记直接重发（对齐飞书/微信）
            onRetrySend: _messageActions.resend,
            onPlayAudio: (source) =>
                ref.read(audioPlayerServiceProvider).play(source),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput(User user, double keyboardInset) {
    return ChatInput(
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
      sendToLabel: '发送给 ${user.name}',
      heightNotifier: _inputAreaHeight,
      // 必须传：ChatInput 靠它把输入行浮到键盘之上、并把面板留在原位被键盘覆盖。
      // 漏传会退回默认值 0，输入行会一直停在屏幕底部被键盘挡住。
      keyboardInset: keyboardInset,
    );
  }

  Widget _buildBody(
    ChatDetailState chatDetailState,
    User user,
    String currentUserId,
  ) {
    // 输入区高度上限：多行输入 + 表情/附件面板可能超出可用高度。
    // 用屏幕可用高度近似，面板内部 Flexible 会在受限时自动收缩兜底。
    // 这里按 aspect 取值（height/padding）：键盘动画期间 viewInsets 逐帧变化不会
    // 触发本页重建；若改用 MediaQuery.maybeOf 会注册无条件依赖，键盘每帧都重建整页。
    // 下限钳到 0：可用高度不足时（小窗/横屏/大字体）BoxConstraints 不接受负数上限。
    final maxInputHeight = math.max(
      0.0,
      (MediaQuery.maybeHeightOf(context) ?? 0) -
          (MediaQuery.maybePaddingOf(context)?.top ?? 0) -
          kToolbarHeight,
    );
    return _bodyReady
        ? Stack(
            children: [
              Column(
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
                  _buildMessageListSection(
                    chatDetailState,
                    user,
                    currentUserId,
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
                ],
              ),
              // 输入区作为覆盖层贴在底部：它不占 body 的布局空间，
              // 因此键盘升降不会牵动消息列表（列表内容不位移）。
              // 对齐飞书实机录屏测得的行为：键盘直接盖在列表之上。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxInputHeight),
                  // 键盘高度只在这个 Builder 的 element 上注册依赖：键盘升降期间
                  // 只重建输入区，不再每帧重建整页（AppBar、消息区骨架、用户对象构造）。
                  child: Builder(
                    builder: (context) => _buildChatInput(
                      user,
                      MediaQuery.viewInsetsOf(context).bottom,
                    ),
                  ),
                ),
              ),
            ],
          )
        : ColoredBox(
            color: context.appColors.background,
            child: const SizedBox.expand(),
          );
  }

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(
      chatDetailViewModelProvider(widget.conversationId),
    );
    final userProfileState = ref.watch(userProfileViewProvider);
    final user = _getUser(userProfileState);
    final conversation = _conversation;
    final otherUserId = conversation?.conversationType == 1
        ? conversation!.userId
        : '';
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
      return _buildMissingConversation();
    }

    // 不包 PopScope：早先 `canPop: false` + 手动 pop 会让 Android 14 的
    // 预测性返回（返回手势预览上一页）失效。退出时的收尾（存草稿、结束输入、
    // 补一次已读）统一放在 dispose 里，返回手势/返回键/顶栏返回三条路径行为一致。
    return Scaffold(
      backgroundColor: context.appColors.background,
      // 键盘不让 Scaffold 缩放 body：
      // resizeToAvoidBottomInset: true 时键盘出现会让整个 body 变矮，消息列表跟着重排；
      // 点表情（收键盘 + 开面板 同一帧）时两次重排叠加，就是真机上的「全局抖动」。
      // 改成 false 后，底部让位由输入区自己按 max(面板, 键盘) 计算并上报
      // （见 _buildMessageListSection 的 bottom padding），只影响列表底部留白。
      resizeToAvoidBottomInset: false,
      appBar: _ChatDetailAppBarHost(
        user: user,
        isTyping: isTyping,
        isGroup: _isGroup,
        otherUserId: otherUserId,
        onBack: () {
          _onUserGoBack();
          Navigator.of(context).pop();
        },
        onOpenSettings: () {
          AppRouter.goToChatSettings(context, conversation);
        },
        onSearch: _showMessageSearch,
      ),
      body: _buildBody(chatDetailState, user, currentUserId),
    );
  }
}

/// 顶栏宿主：把「对方在线状态」的订阅限制在顶栏自身。
///
/// 原先会话详情页在 build 里 `ref.watch(userOnlineStatusProvider(...))`，
/// presence 每次变化都会重建整页（真机实测：`user_status_changed` 回调后紧接
/// 一次整页 build）。下沉到这里后只有顶栏重建，[ChatDetailAppBar] 的接口和
/// 单测都保持不变。
class _ChatDetailAppBarHost extends ConsumerWidget
    implements PreferredSizeWidget {
  const _ChatDetailAppBarHost({
    required this.user,
    required this.isTyping,
    required this.isGroup,
    required this.otherUserId,
    required this.onBack,
    required this.onOpenSettings,
    required this.onSearch,
  });

  final User user;
  final bool isTyping;
  final bool isGroup;

  /// 需要展示在线状态的对方 userId；群聊或空值时传空串，表示不订阅。
  final String otherUserId;

  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = otherUserId.isEmpty
        ? null
        : ref.watch(userOnlineStatusProvider(otherUserId));
    return ChatDetailAppBar(
      user: user,
      isTyping: isTyping,
      isGroup: isGroup,
      online: online,
      onBack: onBack,
      onOpenSettings: onOpenSettings,
      onSearch: onSearch,
    );
  }
}
