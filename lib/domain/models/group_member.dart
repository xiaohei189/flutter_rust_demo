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
    /// 禁言结束时间；`null` 表示当前未被禁言（服务端用 0 表示未禁言）。
    DateTime? muteEndTime,
  }) = _GroupMember;
}

extension GroupMemberJoinTime on GroupMember {
  int get joinTimeMs => joinTime?.millisecondsSinceEpoch ?? 0;
}

extension GroupMemberMute on GroupMember {
  /// 相对给定时间是否处于禁言中（禁言到期时间在未来）。
  bool isMutedAt(DateTime now) {
    final end = muteEndTime;
    return end != null && end.isAfter(now);
  }

  /// 禁言剩余时长；未禁言时返回 `null`。
  Duration? muteRemainingAt(DateTime now) {
    final end = muteEndTime;
    if (end == null || !end.isAfter(now)) return null;
    return end.difference(now);
  }
}
