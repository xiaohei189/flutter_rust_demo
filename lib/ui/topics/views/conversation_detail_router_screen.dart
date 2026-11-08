import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/group.dart';
import '../../../domain/models/group_mode.dart';
import '../../chat/providers/conversation_provider.dart';
import '../../chat/views/chat_detail_screen.dart';
import '../../groups/providers/group_provider.dart';
import 'topic_group_screen.dart';

class ConversationDetailRouterScreen extends ConsumerStatefulWidget {
  const ConversationDetailRouterScreen({
    super.key,
    required this.conversationId,
    this.preLoaded = false,
    this.focusAtMe = false,
    this.initialMessageId,
  });

  final String conversationId;
  final bool preLoaded;
  final bool focusAtMe;
  final String? initialMessageId;

  @override
  ConsumerState<ConversationDetailRouterScreen> createState() =>
      _ConversationDetailRouterScreenState();
}

class _ConversationDetailRouterScreenState
    extends ConsumerState<ConversationDetailRouterScreen> {
  Future<Group?>? _groupFuture;

  @override
  void initState() {
    super.initState();
    _groupFuture = _loadGroup();
  }

  Future<Group?> _loadGroup() async {
    final conversation = ref.read(
      conversationByIdProvider(widget.conversationId),
    );
    if (conversation == null || conversation.conversationType == 1) return null;
    final groupId = conversation.groupId.isNotEmpty
        ? conversation.groupId
        : widget.conversationId.startsWith('sg_')
        ? widget.conversationId.substring(3)
        : '';
    if (groupId.isEmpty) return null;
    final cached = ref
        .read(groupListProvider)
        .groups
        .where((group) => group.groupId == groupId)
        .firstOrNull;
    try {
      final groups = await ref.read(groupRepositoryProvider).getGroupsInfo([
        groupId,
      ]);
      final remote = groups
          .where((group) => group.groupId == groupId)
          .firstOrNull;
      if (remote?.ex.isNotEmpty == true || cached == null) {
        return remote;
      }
      // 群资料接口在部分服务端版本上会丢失 ex；本地已同步的群模式仍然有效，
      // 不能因此把话题群错误降级成普通聊天。
      return cached;
    } catch (_) {
      return cached;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(
      conversationByIdProvider(widget.conversationId),
    );
    if (conversation == null || conversation.conversationType == 1) {
      return ChatDetailScreen(
        conversationId: widget.conversationId,
        preLoaded: widget.preLoaded,
        focusAtMe: widget.focusAtMe,
        initialMessageId: widget.initialMessageId,
      );
    }
    return FutureBuilder<Group?>(
      future: _groupFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final group = snapshot.data;
        if (group?.mode == GroupMode.topic) {
          return TopicGroupScreen(
            conversationId: widget.conversationId,
            group: group,
          );
        }
        return ChatDetailScreen(
          conversationId: widget.conversationId,
          preLoaded: widget.preLoaded,
          focusAtMe: widget.focusAtMe,
          initialMessageId: widget.initialMessageId,
        );
      },
    );
  }
}
