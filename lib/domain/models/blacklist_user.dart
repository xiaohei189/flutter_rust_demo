import 'package:freezed_annotation/freezed_annotation.dart';

part 'blacklist_user.freezed.dart';

@freezed
class BlacklistUser with _$BlacklistUser {
  const factory BlacklistUser({
    required String userId,
    required String nickname,
    required String faceUrl,
  }) = _BlacklistUser;
}
