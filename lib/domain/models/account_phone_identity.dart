/// 当前账号在账号服务中的手机号。
///
/// OpenIM 核心用户资料接口返回的 `telephone` 通常为空；登录手机号属于
/// 账号服务字段 `phoneNumber`，因此单独建模避免与联系资料中的固定电话混淆。
class AccountPhoneIdentity {
  const AccountPhoneIdentity({
    required this.areaCode,
    required this.phoneNumber,
  });

  final String areaCode;
  final String phoneNumber;

  bool get isEmpty => phoneNumber.trim().isEmpty;

  String get displayText {
    final phone = phoneNumber.trim();
    if (phone.isEmpty) return '';

    final area = areaCode.trim();
    if (area.isEmpty || phone.startsWith('+')) return phone;
    return '$area $phone';
  }
}
