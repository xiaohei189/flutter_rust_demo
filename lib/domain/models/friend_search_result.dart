import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_search_result.freezed.dart';

@freezed
class FriendSearchResult with _$FriendSearchResult {
  const factory FriendSearchResult({
    required String userId,
    required String nickname,
    required String faceUrl,
    required String remark,
    required String ex,
    required int relationship,
    DateTime? createdTime,
  }) = _FriendSearchResult;
}
