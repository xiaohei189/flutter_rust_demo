import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String userId,
    required String nickname,
    required String faceUrl,
    required int gender,
    required String telephone,
    required String email,
    required String remark,
    required int globalRecvMsgOpt,
  }) = _UserProfile;
}
