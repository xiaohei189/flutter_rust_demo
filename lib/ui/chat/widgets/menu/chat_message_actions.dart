import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/message.dart' show MessageType;
import '../../../../domain/models/user.dart';
import '../../../../router/app_router.dart';
import '../../../contacts/widgets/contact_pick_item.dart' show ContactPickItem;
import '../../mappers/message_display.dart';
import '../../view_models/chat_detail_view_model.dart';
import '../media_viewer.dart';
import '../message_content_type.dart' show MessageContentType;
import 'chat_dialogs.dart'
    show
        showCustomMessageDialog,
        showDeleteMessagesConfirm,
        showLocationDetailDialog,
        showMergeForwardTitleDialog;
import 'file_actions_sheet.dart' show showFileActionsSheet;

/// 聊天页消息操作：发送、复制、撤回、删除、重发、表情、置顶、转发、文件与消息点击路由。
/// 与 [ChatMediaActions] 一样由页面持有，方法按需接收 [BuildContext]。
class ChatMessageActions {
  ChatMessageActions({
    required this.viewModel,
    required this.preLoaded,
    required this.readState,
    required this.onError,
    required this.onClearComposer,
    required this.onScrollToBottom,
  });

  final ChatDetailViewModel viewModel;
  final bool preLoaded;
  final ChatDetailState Function() readState;
  final void Function(String message) onError;
  final VoidCallback onClearComposer;
  final VoidCallback onScrollToBottom;

  String? get _errorText => readState().errorText;

  Future<void> sendText(String text, MessageContentType type) async {
    // 返回「本地是否已受理」：受理后输入框即可清空（对齐 Go Demo：本地消息
    // add 之后立刻 clear），网络失败由气泡状态 + 页面提示呈现。
    final accepted = await viewModel.sendText(text, type);
    if (accepted) {
      onClearComposer();
      if (!preLoaded) onScrollToBottom();
    } else {
      onError(_errorText ?? '发送消息失败');
    }
  }

  Future<void> revoke(ChatMessage message) async {
    final ok = await viewModel.revokeMessage(message);
    if (!ok) onError(_errorText ?? '撤回失败');
  }

  Future<void> delete(ChatMessage message) async {
    final ok = await viewModel.deleteMessage(message);
    if (!ok) onError(_errorText ?? '删除失败');
  }

  Future<void> resend(ChatMessage message) async {
    final accepted = await viewModel.resendMessage(message);
    if (!accepted) onError(_errorText ?? '消息重发失败');
  }

  void copy(ChatMessage message, BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  }

  /// 表情回复：写入本地扩展（退出会话重进后仍在）。
  Future<void> toggleReaction(ChatMessage message, String emoji) async {
    await viewModel.toggleReaction(message, emoji);
  }

  /// 置顶/取消置顶消息：同样落在本地扩展里。
  Future<void> togglePin(ChatMessage message, BuildContext context) async {
    final pinned = await viewModel.togglePin(message);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pinned ? '已置顶' : '已取消置顶'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> forward(ChatMessage message, BuildContext context) async {
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '转发给',
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final target = result.first;
    final ok = await viewModel.forwardSelectedMessages(
      messages: [message],
      targetId: target.id,
      isGroup: target.isGroup,
      merge: false,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已转发给 ${target.name}')));
    }
  }

  Future<void> forwardSelected(
    BuildContext context, {
    required bool merge,
  }) async {
    final selected = readState().selectedMessages;
    if (selected.isEmpty) return;
    final forwardable = selected
        .where((m) => m.status != 3 && m.status != 4)
        .toList();
    if (forwardable.isEmpty) {
      onError('暂无可转发的消息');
      return;
    }
    if (forwardable.length > 100) {
      onError('最多可一次转发 100 条消息');
      return;
    }
    var title = '聊天记录';
    if (merge) {
      final edited = await showMergeForwardTitleDialog(context, title);
      if (edited == null || !context.mounted) return;
      title = edited.trim().isEmpty ? '聊天记录' : edited.trim();
    }
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '选择转发目标',
      multiSelect: true,
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final ok = await viewModel.forwardSelectedMessagesToTargets(
      messages: forwardable,
      targets: result.map((t) => (id: t.id, isGroup: t.isGroup)).toList(),
      merge: merge,
      title: title,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已转发 ${forwardable.length} 条消息给 ${result.length} 个会话'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (context.mounted) {
      final error = _errorText ?? '转发失败';
      if (viewModel.hasFailedForwardTargets) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '重试',
              onPressed: () => retryForward(context),
            ),
          ),
        );
      } else {
        onError(error);
      }
    }
  }

  Future<void> retryForward(BuildContext context) async {
    final ok = await viewModel.retryFailedForwardTargets();
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('重试转发成功'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (context.mounted) {
      onError(_errorText ?? '重试转发失败');
    }
  }

  Future<void> deleteSelected(BuildContext context) async {
    final count = readState().selectedMessages.length;
    final confirmed = await showDeleteMessagesConfirm(context, count);
    if (!confirmed || !context.mounted) return;
    final ok = await viewModel.deleteSelectedMessages();
    if (!ok && context.mounted) {
      onError(_errorText ?? '删除失败');
    }
  }

  void handleTap(ChatMessage message, BuildContext context) {
    if (readState().selectMode) {
      viewModel.toggleMessageSelection(message);
      return;
    }
    switch (message.messageType) {
      case MessageType.merge:
        AppRouter.goToMergeMessage(context, message);
      case MessageType.image:
        final source = message.displayImageSource;
        if (source.isNotEmpty) {
          openImagePreview(
            context,
            source: source,
            suggestedName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      case MessageType.video:
        openVideoPreview(context, source: message.videoSource);
      case MessageType.file:
        showFileActions(message, context);
      case MessageType.card:
        if (message.cardUserId.isNotEmpty) {
          AppRouter.goToUserProfile(
            context,
            userId: message.cardUserId,
            user: User(
              id: message.cardUserId,
              name: message.cardNickname.isNotEmpty
                  ? message.cardNickname
                  : message.cardUserId,
              avatar: message.cardFaceUrl.isNotEmpty
                  ? message.cardFaceUrl
                  : null,
            ),
          );
        }
      case MessageType.location:
        showLocationDetail(message, context);
      case MessageType.custom:
        showCustomMessageDialog(context, message.displayText);
      default:
        break;
    }
  }

  Future<void> showFileActions(
    ChatMessage message,
    BuildContext context,
  ) async {
    final action = await showFileActionsSheet(context);
    if (action == null || !context.mounted) return;

    final source = message.fileSource;
    final name = message.fileName.isNotEmpty
        ? message.fileName
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    if (action == 'save') {
      await saveMessageMedia(context, source: source, suggestedName: name);
      return;
    }

    if (source.isEmpty) {
      onError('文件地址为空，无法打开');
      return;
    }
    try {
      final ok = await viewModel.openFile(source: source, fileName: name);
      if (!ok && context.mounted) {
        onError('没有可打开该文件的应用，可尝试保存后打开');
      }
    } catch (e) {
      onError('打开文件失败: $e');
    }
  }

  void showLocationDetail(ChatMessage message, BuildContext context) {
    showLocationDetailDialog(context, message);
  }
}
