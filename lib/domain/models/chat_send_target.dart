import 'chat_session_type.dart';
import 'conversation.dart';
import 'conversation_extensions.dart';

/// 发送消息的目标（由会话推导）。
///
/// - `recvId`：单聊取对方 userID，群聊取群 ID；
/// - `sessionType` / `groupId`：群聊需要，单聊 `groupId` 为空。
typedef ChatSendTarget = ({
  String recvId,
  ChatSessionType sessionType,
  String groupId,
});

/// 按会话推导发送目标；推导不出对方/群 ID 时返回 `null`。
ChatSendTarget? chatSendTargetOf(
  Conversation conversation,
  String currentUserId,
) {
  final cid = conversation.conversationId;
  final int type = conversation.conversationType;
  String recvId;
  switch (type) {
    case 1:
      recvId = conversation.userId;
      if (recvId.isEmpty && cid.startsWith('si_')) {
        final parts = cid.split('_');
        if (parts.length >= 3) {
          recvId = parts[1] == currentUserId ? parts[2] : parts[1];
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
  final groupId =
      (sessionType == ChatSessionType.writeGroupChat ||
          sessionType == ChatSessionType.readGroupChat)
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
