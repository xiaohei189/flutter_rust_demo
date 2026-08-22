import '../../domain/models/user_profile.dart';
import '../../generated/rust/model/user.dart' show UserInfo;

/// 用户资料领域模型与生成的 UserInfo 之间的映射。
class UserProfileMapper {
  const UserProfileMapper._();

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