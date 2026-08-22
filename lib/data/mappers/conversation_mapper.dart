import '../../domain/models/conversation.dart';
import '../../generated/rust/model/local.dart' show LocalConversation;

/// 会话领域模型与生成的 LocalConversation 之间的映射。
class ConversationMapper {
  const ConversationMapper._();

  static Conversation fromLocalConversation(LocalConversation raw) {
    return Conversation(
      conversationId: raw.conversationId,
      conversationType: raw.conversationType,
      userId: raw.userId,
      groupId: raw.groupId,
      showName: raw.showName,
      faceUrl: raw.faceUrl,
      latestMsg: raw.latestMsg,
      latestMsgSendTime: raw.latestMsgSendTime.toInt(),
      unreadCount: raw.unreadCount,
      recvMsgOpt: raw.recvMsgOpt,
      isPinned: raw.isPinned,
      isPrivateChat: raw.isPrivateChat,
      burnDuration: raw.burnDuration,
      groupAtType: raw.groupAtType,
      isNotInGroup: raw.isNotInGroup,
      updateUnreadCountTime: raw.updateUnreadCountTime.toInt(),
      attachedInfo: raw.attachedInfo,
      ex: raw.ex,
      draftText: raw.draftText,
      draftTextTime: raw.draftTextTime.toInt(),
      maxSeq: raw.maxSeq.toInt(),
      minSeq: raw.minSeq.toInt(),
      isMsgDestruct: raw.isMsgDestruct,
      msgDestructTime: raw.msgDestructTime.toInt(),
    );
  }
}