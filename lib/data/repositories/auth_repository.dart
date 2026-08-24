import '../../domain/models/auth.dart';
import '../services/auth_api.dart' as auth_api;
import '../services/login_storage.dart';

/// 认证仓库：封装验证码/登录/注册 HTTP 与本地凭证存储，
/// 向 ViewModel 返回领域模型 [AuthSession]，隔离 data 层细节。
abstract class AuthRepository {
  /// 认证服务端基础地址（用于错误提示）。
  String get authBaseUrl;

  Future<void> sendVerificationCode({
    required String areaCode,
    required String phoneNumber,
    required VerificationCodeUsage usedFor,
  });

  Future<AuthSession> loginWithPassword({
    required String areaCode,
    required String phoneNumber,
    required String password,
    required int platform,
  });

  Future<AuthSession> loginWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String verifyCode,
    required int platform,
  });

  Future<AuthSession> registerWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String nickname,
    required String verifyCode,
    required int platform,
  });

  Future<void> saveCredentials({
    required String userId,
    required String imToken,
    String areaCode = '+86',
    String phoneNumber = '',
  });

  Future<LoginCredentials?> loadCredentials();

  Future<void> clearCredentials();
}

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl();

  @override
  String get authBaseUrl => auth_api.kAuthBaseUrl;

  @override
  Future<void> sendVerificationCode({
    required String areaCode,
    required String phoneNumber,
    required VerificationCodeUsage usedFor,
  }) {
    return auth_api.sendVerificationCode(
      areaCode: areaCode,
      phoneNumber: phoneNumber,
      usedFor: usedFor.rawValue,
    );
  }

  @override
  Future<AuthSession> loginWithPassword({
    required String areaCode,
    required String phoneNumber,
    required String password,
    required int platform,
  }) async {
    final result = await auth_api.loginAsync(
      areaCode: areaCode,
      phoneNumber: phoneNumber,
      password: password,
      platform: platform,
    );
    return AuthSession(userId: result.userId, imToken: result.imToken);
  }

  @override
  Future<AuthSession> loginWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String verifyCode,
    required int platform,
  }) async {
    final result = await auth_api.loginWithVerifyCode(
      areaCode: areaCode,
      phoneNumber: phoneNumber,
      verifyCode: verifyCode,
      platform: platform,
    );
    return AuthSession(userId: result.userId, imToken: result.imToken);
  }

  @override
  Future<AuthSession> registerWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String nickname,
    required String verifyCode,
    required int platform,
  }) async {
    final result = await auth_api.registerWithVerifyCode(
      areaCode: areaCode,
      phoneNumber: phoneNumber,
      nickname: nickname,
      verifyCode: verifyCode,
      platform: platform,
    );
    return AuthSession(userId: result.userId, imToken: result.imToken);
  }

  @override
  Future<void> saveCredentials({
    required String userId,
    required String imToken,
    String areaCode = '+86',
    String phoneNumber = '',
  }) {
    return LoginStorage.saveCredentials(
      userId: userId,
      imToken: imToken,
      areaCode: areaCode,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<LoginCredentials?> loadCredentials() {
    return LoginStorage.loadCredentials();
  }

  @override
  Future<void> clearCredentials() {
    return LoginStorage.clearCredentials();
  }
}
