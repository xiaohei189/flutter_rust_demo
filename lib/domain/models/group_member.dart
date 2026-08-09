import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_member.freezed.dart';

@freezed
class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String groupId,
    required String userId,
    required String nickname,
    required String faceUrl,
    required int roleLevel,
    required String joinSource,
    DateTime? joinTime,
  }) = _GroupMember;
}

extension GroupMemberJoinTime on GroupMember {
  int get joinTimeMs => joinTime?.millisecondsSinceEpoch ?? 0;
}
