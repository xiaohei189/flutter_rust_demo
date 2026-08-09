import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/message_ext.dart';
import '../models/message.dart' show MessageType;
import '../providers/providers.dart';
import '../services/message_service_notifier.dart';
import '../src/rust/ffi/message_advanced.dart' show sendTyping;
import '../src/rust/ffi/message.dart' show sendMergerMessage;
import '../src/rust/model/message.dart' show MessageInfo;
import '../src/rust/model/group.dart' show GroupMember;
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../extensions/conversation_extensions.dart';
import '../models/user.dart';
import '../src/rust/constant/enums.dart' show SessionType;
import '../src/rust/model/local.dart' show LocalChatLog, LocalConversation;
import '../widgets/chat_input.dart' show ChatInput, MessageContentType;
import '../widgets/message_list.dart';
import '../widgets/message_action_menu.dart';
import '../widgets/user_avatar.dart';
import '../screens/contact_picker_screen.dart';
import '../screens/merge_message_detail_screen.dart';

/// 聊天详情页：顶栏（返回+未读、昵称+在线/成员数、更多）、消息区、底部输入区
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

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(false);
  bool _hasMoreHistory = true;
  bool _bodyReady = false;
  DateTime? _lastTypingSent;
  MessageInfo? _quotedMessage;
  final List<String> _atUserIds = [];
  bool _selectMode = false;
  final List<MessageInfo> _selectedMessages = [];
  MessageServiceNotifier? _messageService; // 缓存引用，避免 dispose 时访问 ref
  StreamSubscription<MessageListState>? _messageListSubscription;
  String _lastMessageListTailId = '';
  DateTime? _lastMarkReadTime; // 防抖：记录上次标记已读时间
  bool? _onlineStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageService = ref.read(messageServiceProvider.notifier);
    _messageService?.setActiveConversation(widget.conversationId);
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
    _messageListSubscription = ref
        .read(messageListProvider(widget.conversationId).notifier)
        .stream
        .listen((_) => _onMessageListChanged());
    _onMessageListChanged();
    // 设置当前选中的会话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedConversationIdProvider.notifier).state = widget.conversationId;
      if (!widget.preLoaded) _loadMessages();
      if (mounted) setState(() => _bodyReady = true);
      _markConversationMessageAsRead();
      _restoreDraft();
      _loadOnlineStatus();
    });
  }

  /// 单聊时查询对方在线状态
  Future<void> _loadOnlineStatus() async {
    final conversation = _conversation;
    if (conversation == null || conversation.conversationType != 1) return;
    final userId = conversation.userId.isNotEmpty ? conversation.userId : null;
    if (userId == null) return;
    final client = ref.read(messageServiceProvider.notifier).client;
    if (client == null) return;
    try {
      final statuses = await client.getUserStatus(userIds: [userId]);
      if (!mounted || statuses.isEmpty) return;
      final online = statuses.first.status == 1;
      setState(() => _onlineStatus = online);
    } catch (_) {
      // 查询失败时保持默认在线展示，不阻塞聊天页
    }
  }

  Future<void> _markConversationMessageAsRead() async {
    // 使用缓存的 service 引用，避免在 dispose 时访问 ref
    final service = _messageService;
    if (service == null) {
      appLog.w('[READ] _messageService 为 null，无法标记已读');
      return;
    }

    // 从缓存的 service 状态中获取会话，避免使用 ref
    final conv = service.currentState.conversations
        .where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;

    if (conv == null) {
      appLog.w('[READ] 会话 ${widget.conversationId} 不在 state 中，无法标记已读');
      return;
    }

    if (conv.unreadCount <= 0) {
      appLog.i('[READ] 会话 ${widget.conversationId} 未读数已是 0，跳过');
      return;
    }

    // 防抖：1秒内只执行一次
    final now = DateTime.now();
    if (_lastMarkReadTime != null && now.difference(_lastMarkReadTime!).inMilliseconds < 1000) {
      return;
    }
    _lastMarkReadTime = now;

    try {
      appLog.i('[READ] 标记会话已读: ${widget.conversationId}, 当前未读数: ${conv.unreadCount}');
      await service.markConversationMessageAsRead(widget.conversationId);
      appLog.i('[READ] 标记会话已读完成: ${widget.conversationId}');
    } catch (e) {
      appLog.e('[READ] 标记已读失败: $e');
    }
  }

  /// 恢复草稿到输入框
  void _restoreDraft() {
    final conv = _conversation;
    if (conv == null) return;
    final draftText = conv.draftText;
    if (draftText.isEmpty) return;
    try {
      final map = jsonDecode(draftText) as Map<String, dynamic>?;
      final text = map?['text'] as String?;
      if (text != null && text.isNotEmpty) {
        _textController.text = text;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
    } catch (_) {
      // 非 JSON 格式，直接作为纯文本恢复
      _textController.text = draftText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: draftText.length),
      );
    }
  }

  /// 离开页面时保存草稿
  void _saveDraftOnExit() {
    final text = _textController.text;
    final service = _messageService;
    if (service == null) return;
    
    final draftText = text.isNotEmpty ? jsonEncode({'text': text}) : '';
    
    // 通过 service 层保存草稿，确保会话列表状态同步更新
    if (text.isNotEmpty) {
      service.saveDraft(widget.conversationId, draftText);
    } else {
      service.clearDraft(widget.conversationId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageListSubscription?.cancel();
    _messageService?.setActiveConversation('');
    _scrollController.removeListener(_onScroll);
    _textController.removeListener(_onTextChanged);
    _loadingNotifier.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 新消息到达后消息列表发生变化时调用：追加到列表并滚动到底部
  void _onMessageListChanged() {
    final messageState = ref.read(messageListProvider(widget.conversationId));
    final messages = messageState.messages;
    if (messages.isEmpty) {
      _lastMessageListTailId = '';
      return;
    }
    final last = messages.last;
    final lastId = last.clientMsgId;
    if (lastId == _lastMessageListTailId) {
      return;
    }
    _lastMessageListTailId = lastId;
    final isOwnMessage = _messageService?.currentState.currentUserId == last.sendId;
    if (!isOwnMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
  }

  /// 用户主动返回时调用：保存草稿并标记已读
  void _onUserGoBack() {
    // 同步保存草稿到内存（异步保存到数据库）
    _saveDraftOnExit();
    // 标记已读（异步，但不需要等待完成）
    _markConversationMessageAsRead();
  }

  /// 获取会话信息
  LocalConversation? get _conversation {
    final convState = ref.read(conversationListProvider);
    return convState.conversations
        .where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
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

    // 从 notifier 获取用户资料缓存
    final cached = conversation.userId.isNotEmpty
        ? ref.read(userProfileProvider.notifier).getUserProfile(conversation.userId)
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

  bool get _isGroup {
    final conversation = _conversation;
    if (conversation == null) return false;
    return conversation.conversationType == 2 ||
        conversation.conversationType == 3;
  }

  Future<void> _loadMessages({bool isLoadMore = false}) async {
    if (_loadingNotifier.value) return;
    if (!_hasMoreHistory && isLoadMore) return;

    appLog.i('[MSG] 加载历史消息: conversationId=${widget.conversationId}, isLoadMore=$isLoadMore');

    // 首次加载时重置 Notifier 的 hasMore 状态，确保能加载消息
    if (!isLoadMore) {
      ref.read(messageListProvider(widget.conversationId).notifier).resetLoadState();
    }

    _loadingNotifier.value = true;

    try {
      final messageState = ref.read(messageListProvider(widget.conversationId));
      final currentMessages = messageState.messages;
      String startClientMsgId = '';

      if (isLoadMore && currentMessages.isNotEmpty) {
        final earliestMsg = currentMessages.first;
        startClientMsgId = earliestMsg.clientMsgId;
      }

      final hasMore = await ref
          .read(messageListProvider(widget.conversationId).notifier)
          .loadHistoryMessages(
            count: 20,
            startClientMsgId: startClientMsgId,
          );

      appLog.i('[MSG] 加载完成: hasMore=$hasMore');
      _hasMoreHistory = hasMore;
      _loadingNotifier.value = false;

      if (!isLoadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom();
        });
      }
    } catch (e) {
      appLog.e('加载历史消息失败: $e');
      _loadingNotifier.value = false;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_hasMoreHistory ||
        _loadingNotifier.value) {
      return;
    }
    final pos = _scrollController.position;
    // reverse ListView: pixels=0 是最新消息(底部)，maxScrollExtent 是最早消息(顶部)
    // 向上滚动到顶部加载更多 → pixels 接近 maxScrollExtent 时触发
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMessages(isLoadMore: true);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      const target = 0.0;
      if (pos.pixels != target) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, MessageContentType type) async {
    if (text.trim().isEmpty) return;

    final connectionState = ref.read(connectionProvider);
    if (!connectionState.isConnected) {
      appLog.e('发送消息失败: WebSocket 未连接');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WebSocket 未连接，无法发送消息'),
            backgroundColor: AppTheme.unreadRed,
          ),
        );
      }
      return;
    }

    final conversation = _conversation;
    if (conversation == null) {
      appLog.e('发送消息失败: 会话不存在');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('会话不存在'),
            backgroundColor: AppTheme.unreadRed,
          ),
        );
      }
      return;
    }

    try {
      final type_ = conversation.conversationType;
      final cid = conversation.conversationId;
      final userProfileState = ref.read(userProfileProvider);
      String recvId;
      switch (type_) {
        case 1:
          recvId = conversation.userId;
          if (recvId.isEmpty && cid.startsWith('si_')) {
            final parts = cid.split('_');
            if (parts.length >= 3) {
              final id1 = parts[1];
              final id2 = parts[2];
              final my = userProfileState.profile?.userId ?? '';
              recvId = id1 == my ? id2 : id1;
            }
          }
          break;
        case 2:
          recvId = cid.startsWith('g_')
              ? cid.substring(2)
              : conversation.groupId;
          break;
        case 3:
          recvId = cid.startsWith('sg_')
              ? cid.substring(3)
              : conversation.groupId;
          break;
        default:
          recvId = '';
      }
      final sessionType = conversation.sessionType;

      if (recvId.isEmpty) {
        appLog.e(
            '发送消息失败: recvId 为空，conversationId=${conversation.conversationId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法发送：会话缺少对方 ID，请返回会话列表重试'),
              backgroundColor: AppTheme.unreadRed,
            ),
          );
        }
        return;
      }

      _textController.clear();

      final groupId = sessionType == SessionType.writeGroupChat || sessionType == SessionType.readGroupChat
          ? (conversation.groupId.isNotEmpty
              ? conversation.groupId
              : cid.startsWith('sg_')
                  ? cid.substring(3)
                  : cid.startsWith('g_')
                      ? cid.substring(2)
                      : '')
          : '';

      // 如果有引用消息，发送引用消息
      final quotedMsg = _quotedMessage;
      if (_atUserIds.isNotEmpty) {
        final atUserIds = List<String>.from(_atUserIds);
        _atUserIds.clear();
        await ref
            .read(messageListProvider(conversation.conversationId).notifier)
            .sendAtTextMessage(
              recvId: recvId,
              text: text,
              atUserIds: atUserIds,
              sessionType: sessionType,
              groupId: groupId,
            );
      } else if (quotedMsg != null) {
        setState(() => _quotedMessage = null);
        final svc = ref.read(messageServiceProvider.notifier);
        await svc.sendQuoteMessage(
          text: text,
          sourceId: recvId,
          sessionType: sessionType,
          quoteText: quotedMsg.content,
          quoteClientMsgId: quotedMsg.clientMsgId,
          quoteSendId: quotedMsg.sendId,
          quoteSendTime: quotedMsg.sendTime.toInt(),
        );
      } else if (type == MessageContentType.markdown) {
        await ref
            .read(messageListProvider(conversation.conversationId).notifier)
            .sendMarkdownMessage(
              recvId: recvId,
              text: text,
              sessionType: sessionType,
              groupId: groupId,
            );
      } else {
        await ref
            .read(messageListProvider(conversation.conversationId).notifier)
            .sendTextMessage(
              recvId: recvId,
              text: text,
              sessionType: sessionType,
              groupId: groupId,
            );
      }

      if (!widget.preLoaded) _scrollToBottom();
    } catch (e, st) {
      appLog.e('发送消息失败: $e', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送消息失败: $e'),
            backgroundColor: AppTheme.unreadRed,
          ),
        );
      }
    }
  }

  // ---- 输入状态 ----

  void _onTextChanged() {
    final now = DateTime.now();
    if (_lastTypingSent != null && now.difference(_lastTypingSent!).inSeconds < 3) return;
    _lastTypingSent = now;
    _sendTyping(focus: true);
  }

  void _sendTyping({required bool focus}) {
    final conversation = _conversation;
    if (conversation == null) return;
    final type = conversation.conversationType;
    String sourceId;
    switch (type) {
      case 1:
        sourceId = conversation.userId;
      case 2:
        sourceId = conversation.groupId;
      case 3:
        sourceId = conversation.groupId;
      default:
        return;
    }
    if (sourceId.isEmpty) return;
    final sessionType = conversation.sessionType;
    sendTyping(sourceId: sourceId, sessionType: sessionType, focus: focus);
  }

  /// 弹出群成员选择器并插入 @ 提及
  Future<void> _showAtMentionPicker() async {
    final target = _getSendTarget();
    if (target == null || target.groupId.isEmpty) return;

    final memberState = ref.read(groupMemberProvider(target.groupId));
    if (memberState.members.isEmpty) {
      await ref.read(groupMemberProvider(target.groupId).notifier).loadMembers();
      if (!mounted) return;
    }
    final members = ref.read(groupMemberProvider(target.groupId)).members;
    if (members.isEmpty) {
      _showError('暂无可选群成员');
      return;
    }

    final selected = await showModalBottomSheet<GroupMember>(
      context: context,
      backgroundColor: Colors.white,
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
                  final m = members[i];
                  return ListTile(
                    leading: UserAvatar(
                      user: User(
                        id: m.userId,
                        name: m.nickname,
                        avatar: m.faceUrl.isNotEmpty ? m.faceUrl : null,
                      ),
                      radius: 18,
                    ),
                    title: Text(m.nickname.isNotEmpty ? m.nickname : m.userId),
                    onTap: () => Navigator.of(ctx).pop(m),
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
    final displayName = selected.nickname.isNotEmpty ? selected.nickname : selected.userId;
    final inserted = '$text$suffix@$displayName ';
    _textController.value = TextEditingValue(
      text: inserted,
      selection: TextSelection.collapsed(offset: inserted.length),
    );
    if (!_atUserIds.contains(selected.userId)) {
      _atUserIds.add(selected.userId);
    }
  }

  /// 打开当前会话的消息搜索
  void _showMessageSearch() {
    final conversation = _conversation;
    if (conversation == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MessageSearchSheet(
        conversationId: conversation.conversationId,
      ),
    );
  }

  // ---- 图片/文件/位置发送 ----

  ({String recvId, SessionType sessionType, String groupId})? _getSendTarget() {
    final conversation = _conversation;
    if (conversation == null) return null;
    final userProfileState = ref.read(userProfileProvider);
    final cid = conversation.conversationId;
    final type = conversation.conversationType;
    String recvId;
    switch (type) {
      case 1:
        recvId = conversation.userId;
        if (recvId.isEmpty && cid.startsWith('si_')) {
          final parts = cid.split('_');
          if (parts.length >= 3) {
            final my = userProfileState.profile?.userId ?? '';
            recvId = parts[1] == my ? parts[2] : parts[1];
          }
        }
      case 2:
        recvId = cid.startsWith('g_') ? cid.substring(2) : conversation.groupId;
      case 3:
        recvId = cid.startsWith('sg_') ? cid.substring(3) : conversation.groupId;
      default:
        recvId = '';
    }
    if (recvId.isEmpty) return null;
    final sessionType = conversation.sessionType;
    final groupId = (sessionType == SessionType.writeGroupChat || sessionType == SessionType.readGroupChat)
        ? (conversation.groupId.isNotEmpty
            ? conversation.groupId
            : cid.startsWith('sg_')
                ? cid.substring(3)
                : cid.startsWith('g_')
                    ? cid.substring(2)
                    : '')
        : '';
    return (recvId: recvId, sessionType: sessionType, groupId: groupId);
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.unreadRed),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final target = _getSendTarget();
    if (target == null) { _showError('会话信息异常'); return; }
    final ok = await ref.read(messageListProvider(_conversation!.conversationId).notifier).sendImageMessage(
      recvId: target.recvId,
      filePath: picked.path,
      sessionType: target.sessionType,
      groupId: target.groupId,
    );
    if (!ok) {
      final err = ref.read(messageListProvider(_conversation!.conversationId)).error;
      _showError(err ?? '发送图片失败');
    }
    if (!widget.preLoaded) _scrollToBottom();
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    final target = _getSendTarget();
    if (target == null) { _showError('会话信息异常'); return; }
    final ok = await ref.read(messageListProvider(_conversation!.conversationId).notifier).sendImageMessage(
      recvId: target.recvId,
      filePath: picked.path,
      sessionType: target.sessionType,
      groupId: target.groupId,
    );
    if (!ok) {
      final err = ref.read(messageListProvider(_conversation!.conversationId)).error;
      _showError(err ?? '发送图片失败');
    }
    if (!widget.preLoaded) _scrollToBottom();
  }

  Future<void> _pickLocation() async {
    // 简单实现：使用默认坐标发送当前位置
    final target = _getSendTarget();
    if (target == null) { _showError('会话信息异常'); return; }
    await ref.read(messageListProvider(_conversation!.conversationId).notifier).sendLocationMessage(
      recvId: target.recvId,
      description: '当前位置',
      latitude: 39.9042,
      longitude: 116.4074,
      sessionType: target.sessionType,
      groupId: target.groupId,
    );
    if (!widget.preLoaded) _scrollToBottom();
  }

  /// 选择并发送文件
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      final target = _getSendTarget();
      if (target == null) { _showError('会话信息异常'); return; }
      await ref.read(messageListProvider(_conversation!.conversationId).notifier).sendFileMessage(
        recvId: target.recvId,
        filePath: file.path!,
        sessionType: target.sessionType,
        groupId: target.groupId,
      );
      if (!widget.preLoaded) _scrollToBottom();
    } catch (e) {
      appLog.e('发送文件失败: $e');
    }
  }

  /// 选择并发送视频
  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      final target = _getSendTarget();
      if (target == null) { _showError('会话信息异常'); return; }
      await ref.read(messageListProvider(_conversation!.conversationId).notifier).sendVideoMessage(
        recvId: target.recvId,
        videoPath: video.path,
        snapshotPath: '',
        sessionType: target.sessionType,
        duration: 0,
        groupId: target.groupId,
      );
      if (!widget.preLoaded) _scrollToBottom();
    } catch (e) {
      appLog.e('发送视频失败: $e');
    }
  }

  /// 发送名片消息
  Future<void> _sendCardMessage(String userId, String nickname, String faceUrl) async {
    try {
      final target = _getSendTarget();
      if (target == null) { _showError('会话信息异常'); return; }
      final svc = ref.read(messageServiceProvider.notifier);
      await svc.sendCardMessage(
        userId: userId,
        nickname: nickname,
        faceUrl: faceUrl,
        ex: '',
        sourceId: target.recvId,
        sessionType: target.sessionType,
      );
      if (!widget.preLoaded) _scrollToBottom();
    } catch (e) {
      appLog.e('发送名片失败: $e');
    }
  }

  // ---- 消息操作 ----

  Future<void> _revokeMessage(dynamic msg) async {
    final message = msg as MessageInfo;
    final conversation = _conversation;
    if (conversation == null) return;
    final svc = ref.read(messageServiceProvider.notifier);
    try {
      await svc.revokeMessage(
        conversationId: conversation.conversationId,
        seq: message.seq.toInt(),
        clientMsgId: message.clientMsgId,
        sessionType: conversation.conversationType,
      );
    } catch (e) {
      _showError('撤回失败: $e');
    }
  }

  Future<void> _deleteMessage(dynamic msg) async {
    final message = msg as MessageInfo;
    final conversation = _conversation;
    if (conversation == null) return;
    final svc = ref.read(messageServiceProvider.notifier);
    try {
      await svc.deleteMessage(
        conversationId: conversation.conversationId,
        clientMsgId: message.clientMsgId,
      );
    } catch (e) {
      _showError('删除失败: $e');
    }
  }

  void _enterSelectMode() {
    setState(() {
      _selectMode = true;
      _selectedMessages.clear();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedMessages.clear();
    });
  }

  void _handleMessageTap(MessageInfo msg) {
    if (_selectMode) {
      setState(() {
        if (_selectedMessages.any((m) => m.clientMsgId == msg.clientMsgId)) {
          _selectedMessages.removeWhere((m) => m.clientMsgId == msg.clientMsgId);
        } else {
          _selectedMessages.add(msg);
        }
      });
      return;
    }
    if (msg.messageType == MessageType.merge) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MergeMessageDetailScreen(message: msg),
        ),
      );
    }
  }

  /// 逐条转发或合并转发选中的消息
  Future<void> _forwardSelected({required bool merge}) async {
    if (_selectedMessages.isEmpty) return;
    final result = await Navigator.push<List<ContactPickItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ContactPickerScreen(
          multiSelect: false,
          title: '选择转发目标',
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    final target = result.first;
    final st = target.isGroup
        ? SessionType.writeGroupChat
        : SessionType.singleChat;
    try {
      if (merge) {
        await sendMergerMessage(
          title: '聊天记录',
          summaryList: _selectedMessages.map((m) => m.displayText).toList(),
          sourceId: target.id,
          sessionType: st,
        );
      } else {
        final svc = ref.read(messageServiceProvider.notifier);
        for (final m in _selectedMessages) {
          await svc.forwardMessage(
            clientMsgId: m.clientMsgId,
            sourceId: target.id,
            sessionType: st,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已转发 ${_selectedMessages.length} 条消息给 ${target.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _exitSelectMode();
    } catch (e) {
      appLog.e('转发失败: $e');
      _showError('转发失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileState = ref.watch(userProfileProvider);
    // 只监听当前会话的未读数，其他会话变化不触发此页重建
    final unread = ref.watch(
      conversationListProvider.select(
        (state) => state.conversations
            .where((c) => c.conversationId == widget.conversationId)
            .firstOrNull
            ?.unreadCount ?? 0,
      ),
    );
    final user = _getUser(userProfileState);
    final conversation = _conversation;
    final currentUserId = userProfileState.profile?.userId ?? '';
    final typingUserId = ref.watch(
      messageServiceProvider.select((s) => s.typingUsers[widget.conversationId]),
    );
    final isTyping = typingUserId != null &&
        typingUserId.isNotEmpty &&
        typingUserId != currentUserId;

    if (conversation == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('会话不存在'),
        ),
        body: const Center(
          child: Text('会话信息不存在或已被删除'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                      decoration: const BoxDecoration(
                        color: AppTheme.unreadRed,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
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
                // 可进入聊天设置/查找聊天记录
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(user: user, radius: 18),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: constraints.maxWidth.isFinite && constraints.maxWidth > 56
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
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        if (isTyping)
                          Text(
                            '对方正在输入...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor.withValues(alpha: 0.9),
                            ),
                          )
                        else if (_isGroup)
                          Text(
                            '群聊',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          )
                        else
                          Text(
                            _onlineStatus == false ? '离线' : '在线',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(
                                alpha: 0.9,
                              ),
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
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索聊天记录',
            onPressed: _showMessageSearch,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              AppRouter.goToChatSettings(context, conversation);
            },
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
                        final isLoading = _loadingNotifier.value;

                      return MessageList(
                        messages: messages,
                        otherUser: user,
                        currentUserId: currentUserId.isNotEmpty ? currentUserId : null,
                        scrollController: _scrollController,
                        isLoading: isLoading,
                        selectMode: _selectMode,
                        selectedClientMsgIds: _selectedMessages
                            .map((m) => m.clientMsgId)
                            .toSet(),
                        cachedCurrentUserProfile: ref.watch(userProfileProvider).profile,
                        onMessageVisible: (msg) {
                          // 逐条标记已读（对齐 Go SDK VisibilityDetector 模式）
                          if (!msg.isRead && msg.sendId != (currentUserId.isNotEmpty ? currentUserId : null)) {
                            _markConversationMessageAsRead();
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
                              final result = await Navigator.push<List<ContactPickItem>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContactPickerScreen(multiSelect: false, title: '转发给'),
                                ),
                              );
                              if (result != null && result.isNotEmpty) {
                                final target = result.first;
                                final st = target.isGroup ? SessionType.writeGroupChat : SessionType.singleChat;
                                try {
                                  final sourceId = target.isGroup ? target.id : target.id;
                                  await ref.read(messageServiceProvider.notifier).forwardMessage(
                                    clientMsgId: msg.clientMsgId,
                                    sourceId: sourceId,
                                    sessionType: st,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已转发给 ${target.name}')),
                                  );
                                  }
                                } catch (e) {
                                  appLog.e('转发失败: $e');
                                }
                              }
                            },
                            onQuote: (msg) {
                              setState(() => _quotedMessage = msg);
                            },
                            onMultiSelect: _enterSelectMode,
                          ),
                        ),
                        onMessageTap: _handleMessageTap,
                      );
                    },
                  ),
                ),
              ),
              // 引用消息提示栏
              if (_selectMode)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已选 ${_selectedMessages.length} 条',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _forwardSelected(merge: false),
                        child: const Text('逐条转发'),
                      ),
                      TextButton(
                        onPressed: () => _forwardSelected(merge: true),
                        child: const Text('合并转发'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _exitSelectMode,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                if (_quotedMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      border: Border(
                        top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '引用 ${_quotedMessage!.senderNickname}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _quotedMessage!.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() => _quotedMessage = null);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
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
                  onAtMention: _showAtMentionPicker,
                  isGroupChat: _isGroup,
                ),
              ],
            )
          : const ColoredBox(
              color: AppTheme.backgroundColor,
              child: SizedBox.expand(),
            ),
    );
  }
}

/// 会话内消息搜索底部面板
class _MessageSearchSheet extends ConsumerStatefulWidget {
  const _MessageSearchSheet({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_MessageSearchSheet> createState() =>
      _MessageSearchSheetState();
}

class _MessageSearchSheetState extends ConsumerState<_MessageSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<LocalChatLog> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final svc = ref.read(messageServiceProvider.notifier);
      final results = await svc.searchLocalMessages(
        conversationId: widget.conversationId,
        keyword: keyword,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '搜索失败: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: '搜索聊天记录',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: AppTheme.unreadRed)),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('没有找到相关消息'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) {
        final log = _results[i];
        final rawTime = log.sendTime.toInt();
        final time = DateTime.fromMillisecondsSinceEpoch(
          rawTime > 0 && rawTime < 946684800000 ? rawTime * 1000 : rawTime,
        ).toLocal();
        return ListTile(
          leading: UserAvatar(
            user: User(
              id: log.sendId,
              name: log.senderNickName,
              avatar: log.senderFaceUrl.isNotEmpty ? log.senderFaceUrl : null,
            ),
            radius: 18,
          ),
          title: Text(
            log.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${log.senderNickName.isNotEmpty ? log.senderNickName : log.sendId}  '
            '${time.toString().substring(0, 16)}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(log.senderNickName.isNotEmpty ? log.senderNickName : log.sendId),
              content: SelectableText(log.content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
