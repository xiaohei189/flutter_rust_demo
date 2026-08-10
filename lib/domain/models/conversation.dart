import 'package:freezed_annotation/freezed_annotation.dart';

import '../../src/rust/model/local.dart' show LocalConversation;

part 'conversation.freezed.dart';

@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String conversationId,
    required int conversationType,
    required String userId,
    required String groupId,
    required String showName,
    required String faceUrl,
    required String latestMsg,
    required int latestMsgSendTime,
    required int unreadCount,
    required int recvMsgOpt,
    required bool isPinned,
    required bool isPrivateChat,
    required int burnDuration,
    required int groupAtType,
    required bool isNotInGroup,
    required int updateUnreadCountTime,
    required String attachedInfo,
    required String ex,
    required String draftText,
    required int draftTextTime,
    required int maxSeq,
    required int minSeq,
    required bool isMsgDestruct,
    required int msgDestructTime,
  }) = _Conversation;
}

extension ConversationMapping on Conversation {
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
