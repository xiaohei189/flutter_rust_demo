import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend.freezed.dart';

@freezed
class Friend with _$Friend {
  const factory Friend({
    required String userId,
    required String nickname,
    required String faceUrl,
    required int gender,
    required String remark,
    required String addSource,
    required String ex,
    DateTime? createdTime,
  }) = _Friend;
}

extension FriendDisplayName on Friend {
  String get displayName => remark.isNotEmpty ? remark : nickname;
}
