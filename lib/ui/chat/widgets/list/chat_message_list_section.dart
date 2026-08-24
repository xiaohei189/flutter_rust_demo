import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/user.dart';
import '../../../chat/providers/message_provider.dart';
import '../../../chat/providers/message_service_provider.dart';
import '../menu/message_action_menu.dart' show MessageActions;
import '../menu/message_hover_toolbar.dart' show MessageReactionGroup;
import 'message_list.dart';

/// 聊天详情页的消息列表区块：只负责消息数据派生与滚动，页面不再整体重建。
class ChatMessageListSection extends ConsumerWidget {
  const ChatMessageListSection({
    super.key,
    required this.conversationId,
    required this.user,
    required this.currentUserId,
    required this.currentUserAvatar,
    required this.scrollController,
    required this.isLoading,
    required this.selectMode,
    required this.selectedClientMsgIds,
    required this.messageReactions,
    required this.onMessageVisible,
    required this.onMessageTap,
    this.messageActionsBuilder,
    this.onPlayAudio,
  });

  final String conversationId;
  final User user;
  final String? currentUserId;
  final String? currentUserAvatar;
  final ScrollController scrollController;
  final bool isLoading;
  final bool selectMode;
  final Set<String> selectedClientMsgIds;
  final Map<String, List<MessageReactionGroup>> messageReactions;
  final void Function(ChatMessage message) onMessageVisible;
  final void Function(ChatMessage message) onMessageTap;
  final MessageActions Function(ChatMessage message)? messageActionsBuilder;
  final void Function(String source)? onPlayAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesByConversationProvider(conversationId));
    final uploadProgress = ref.watch(
      messageServiceProvider.select((s) => s.uploadProgress),
    );
    final groupReadReceipts = ref.watch(
      messageServiceProvider.select((s) => s.groupReadReceipts),
    );
    final cachedCurrentUserProfile = ref.watch(
      messageServiceProvider.select((s) => s.loginUserProfile),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => FocusScope.of(context).unfocus(),
      child: MessageList(
        messages: messages,
        otherUser: user,
        currentUserId: currentUserId,
        currentUserAvatar: currentUserAvatar,
        scrollController: scrollController,
        isLoading: isLoading,
        selectMode: selectMode,
        selectedClientMsgIds: selectedClientMsgIds,
        uploadProgress: uploadProgress,
        groupReadReceipts: groupReadReceipts,
        cachedCurrentUserProfile: cachedCurrentUserProfile,
        onMessageVisible: onMessageVisible,
        messageActionsBuilder: messageActionsBuilder,
        messageReactions: messageReactions,
        onMessageTap: onMessageTap,
        onPlayAudio: onPlayAudio,
      ),
    );
  }
}
