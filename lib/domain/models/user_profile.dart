import 'package:freezed_annotation/freezed_annotation.dart';

import '../../generated/rust/model/user.dart' show UserInfo;

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

extension UserProfileMapping on UserProfile {
  static UserProfile fromUserInfo(UserInfo info) {
    return UserProfile(
      userId: info.userId,
      nickname: info.nickname,
      faceUrl: info.faceUrl,
      gender: info.gender,
      telephone: info.telephone,
      email: info.email,
      remark: info.remark,
      globalRecvMsgOpt: info.globalRecvMsgOpt,
    );
  }
}
