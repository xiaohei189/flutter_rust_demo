import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/message.dart' show MessageType;
import '../../../domain/models/group_member.dart';
import '../../../domain/extensions/message_ext.dart';
import '../../../domain/models/user.dart';
import '../../../domain/models/message_search_result.dart' show MessageSearchResult;
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../providers/online_status_provider.dart';
import '../../../router/app_router.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';
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
import '../widgets/chat_message_search_sheet.dart';
import '../widgets/media_viewer.dart';
import '../widgets/menu/message_action_menu.dart';
import '../widgets/menu/chat_dialogs.dart' show showDeleteMessagesConfirm, showLocationDetailDialog;
import '../widgets/menu/message_hover_toolbar.dart' show MessageReactionGroup;
import '../widgets/list/message_list.dart';
import '../widgets/menu/message_selection_bar.dart';
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
    final displayName = selected.nickname.isNotEmpty
        ? selected.nickname
        : selected.userId;
    _insertAtMention(displayName, selected.userId);
  }

  void _insertAtMention(String displayName, String userId) {
    final text = _textController.text;
    final suffix = text.isEmpty || text.endsWith(' ') ? '' : ' ';
    final inserted = '$text$suffix@$displayName ';
    _textController.value = TextEditingValue(
      text: inserted,
      selection: TextSelection.collapsed(offset: inserted.length),
    );
    _viewModel?.addAtUserId(userId);
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

  Future<void> _pickImages() => _mediaActions.pickImages(context);

  Future<void> _pickFromCamera() => _mediaActions.pickFromCamera(context);

  Future<void> _pickLocation() => _mediaActions.pickLocation(context);

  Future<void> _pickFile() => _mediaActions.pickFile(context);

  Future<void> _pickVideo() => _mediaActions.pickVideo(context);

  Future<void> _sendVoiceMessage(int duration, String filePath) =>
      _mediaActions.sendVoiceMessage(duration, filePath);

  Future<void> _sendCardMessage() => _mediaActions.sendCardMessage(context);

  Future<void> _revokeMessage(dynamic msg) async {
    final ok = await _viewModel?.revokeMessage(msg as ChatMessage) ?? false;
    if (!ok) _showError(_chatState.errorText ?? '撤回失败');
  }

  Future<void> _deleteMessage(dynamic msg) async {
    final ok = await _viewModel?.deleteMessage(msg as ChatMessage) ?? false;
    if (!ok) _showError(_chatState.errorText ?? '删除失败');
  }

  Future<void> _resendMessage(ChatMessage msg) async {
    final ok = await _viewModel?.resendMessage(msg) ?? false;
    if (!ok) _showError(_chatState.errorText ?? '消息重发失败');
  }

  void _copyMessage(ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  }

  void _toggleMessageReaction(ChatMessage msg, String emoji) {
    setState(() {
      final groups = List<MessageReactionGroup>.from(
        _messageReactions[msg.clientMsgId] ?? const [],
      );
      final index = groups.indexWhere((group) => group.emoji == emoji);
      if (index == -1) {
        groups.add(
          MessageReactionGroup(emoji: emoji, count: 1, names: const ['我']),
        );
      } else {
        final group = groups[index];
        if (group.names.contains('我')) {
          final names = group.names.where((name) => name != '我').toList();
          if (names.isEmpty) {
            groups.removeAt(index);
          } else {
            groups[index] = MessageReactionGroup(
              emoji: emoji,
              count: names.length,
              names: names,
            );
          }
        } else {
          groups[index] = MessageReactionGroup(
            emoji: emoji,
            count: group.count + 1,
            names: [...group.names, '我'],
          );
        }
      }
      _messageReactions[msg.clientMsgId] = groups;
    });
  }

  void _toggleMessagePin(ChatMessage msg) {
    final isPinned = _pinnedMessageIds.contains(msg.clientMsgId);
    setState(() {
      if (isPinned) {
        _pinnedMessageIds.remove(msg.clientMsgId);
      } else {
        _pinnedMessageIds.add(msg.clientMsgId);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPinned ? '已取消置顶' : '已置顶'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _sendQuickReply(ChatMessage msg, String text) =>
      _sendMessage(text, MessageContentType.text);

  MessageActions _buildMessageActions(ChatMessage msg) {
    return MessageActions(
      onCopy: _copyMessage,
      onRevoke: _revokeMessage,
      onDelete: _deleteMessage,
      onForward: (message) => _forwardMessage(message),
      onQuote: (message) => _viewModel?.setQuotedMessage(message),
      onMultiSelect: () => _viewModel?.enterSelectMode(),
      onResend: _resendMessage,
      onPin: _toggleMessagePin,
      onReaction: _toggleMessageReaction,
      onQuickReply: _sendQuickReply,
    );
  }

  Future<void> _forwardMessage(ChatMessage msg) async {
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '转发给',
    );
    if (result == null || result.isEmpty || !mounted) return;
    final target = result.first;
    final ok =
        await _viewModel?.forwardSelectedMessages(
              messages: [msg],
              targetId: target.id,
              isGroup: target.isGroup,
              merge: false,
            ) ??
        false;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已转发给 ${target.name}')),
      );
    }
  }

  void _handleMessageTap(ChatMessage msg) {
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

  Future<void> _showFileActions(ChatMessage msg) async {
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

  void _showLocationDetail(ChatMessage msg) {
    showLocationDetailDialog(context, msg);
  }

  Future<void> _forwardSelected({required bool merge}) async {
    final selected = ref
        .read(chatDetailViewModelProvider(widget.conversationId))
        .selectedMessages;
    if (selected.isEmpty) return;
    final forwardable = selected
        .where((m) => m.status != 3 && m.status != 4)
        .toList();
    if (forwardable.isEmpty) {
      _showError('暂无可转发的消息');
      return;
    }
    if (forwardable.length > 100) {
      _showError('最多可一次转发 100 条消息');
      return;
    }
    var title = '聊天记录';
    if (merge) {
      var input = title;
      final edited = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('合并转发标题'),
            content: TextField(
              maxLength: 40,
              onChanged: (value) => input = value,
              decoration: const InputDecoration(hintText: '请输入合并转发标题'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(input),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      if (edited == null || !mounted) return;
      title = edited.trim().isEmpty ? '聊天记录' : edited.trim();
    }
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '选择转发目标',
      multiSelect: true,
    );
    if (result == null || result.isEmpty || !mounted) return;
    final ok =
        await _viewModel?.forwardSelectedMessagesToTargets(
          messages: forwardable,
          targets: result.map((t) => (id: t.id, isGroup: t.isGroup)).toList(),
          merge: merge,
          title: title,
        ) ??
        false;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已转发 ${forwardable.length} 条消息给 ${result.length} 个会话'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      final error = _chatState.errorText ?? '转发失败';
      if (_viewModel?.hasFailedForwardTargets == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: '重试', onPressed: _retryForward),
          ),
        );
      } else {
        _showError(error);
      }
    }
  }

  Future<void> _deleteSelected() async {
    final count = _chatState.selectedMessages.length;
    final confirmed = await showDeleteMessagesConfirm(context, count);
    if (!confirmed || !mounted) return;
    final ok = await _viewModel?.deleteSelectedMessages() ?? false;
    if (!ok && mounted) {
      _showError(_chatState.errorText ?? '删除失败');
    }
  }

  Future<void> _retryForward() async {
    final ok = await _viewModel?.retryFailedForwardTargets() ?? false;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('重试转发成功'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      _showError(_chatState.errorText ?? '重试转发失败');
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
                    Consumer(
                      builder: (context, ref, _) {
                        final messages = ref
                            .watch(messageListProvider(widget.conversationId))
                            .messages
                            .where((m) => m.messageType != MessageType.system)
                            .toList();
                        return MessageSelectionTopBar(
                          count: chatDetailState.selectedMessages.length,
                          totalCount: messages.length,
                          onSelectAll: () => _viewModel?.toggleSelectAll(),
                          onClose: () => _viewModel?.exitSelectMode(),
                          onDelete: _deleteSelected,
                          onForwardOneByOne: () =>
                              _forwardSelected(merge: false),
                          onMergeForward: () => _forwardSelected(merge: true),
                        );
                      },
                    ),
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
                            messageActionsBuilder: _buildMessageActions,
                            messageReactions: _messageReactions,
                            onMessageTap: _handleMessageTap,
                          );
                        },
                      ),
                    ),
                  ),
                  if (chatDetailState.isForwarding)
                    Container(
                      color: context.appColors.surface,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        children: [
                          Text(
                            '转发中 ${chatDetailState.forwardDone}/${chatDetailState.forwardTotal}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: chatDetailState.forwardTotal == 0
                                  ? 0
                                  : chatDetailState.forwardDone /
                                        chatDetailState.forwardTotal,
                              minHeight: 3,
                              backgroundColor: context.appColors.surfaceMuted,
                              color: context.appColors.primary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _viewModel?.cancelForward(),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
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
