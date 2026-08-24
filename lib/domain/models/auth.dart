/// 验证码用途（与账号服务中间件约定一致：1=注册 2=重置密码 3=登录）。
enum VerificationCodeUsage {
  register(1),
  resetPassword(2),
  login(3);

  const VerificationCodeUsage(this.rawValue);

  /// 服务端要求的整型取值。
  final int rawValue;
}

/// 认证成功后的会话信息（登录/注册成功后用于保存凭证与初始化 SDK）。
class AuthSession {
  final String userId;
  final String imToken;

  const AuthSession({required this.userId, required this.imToken});
}
