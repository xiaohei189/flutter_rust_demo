import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_application.freezed.dart';

@freezed
class FriendApplication with _$FriendApplication {
  const factory FriendApplication({
    required String userId,
    required String nickname,
    required String faceUrl,
    required int gender,
    required int addSource,
    required String ex,
    required int handleResult,
    String? reqMsg,
    String? handleMsg,
    DateTime? createdTime,
  }) = _FriendApplication;
}
