import 'package:freezed_annotation/freezed_annotation.dart';

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
