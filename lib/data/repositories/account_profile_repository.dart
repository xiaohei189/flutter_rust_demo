import '../../core/utils/app_logger.dart';
import '../../domain/models/account_phone_identity.dart';
import '../services/account_profile_api.dart';
import '../services/login_storage.dart';

typedef LoadLoginCredentials = Future<LoginCredentials?> Function();

/// 当前登录账号手机号解析。
abstract class AccountProfileRepository {
  Future<AccountPhoneIdentity?> resolveCurrentUserPhone({
    required String userId,
  });
}

class AccountProfileRepositoryImpl implements AccountProfileRepository {
  AccountProfileRepositoryImpl({
    required AccountProfileApi api,
    LoadLoginCredentials? loadCredentials,
  }) : _api = api,
       _loadCredentials = loadCredentials ?? LoginStorage.loadCredentials;

  final AccountProfileApi _api;
  final LoadLoginCredentials _loadCredentials;

  @override
  Future<AccountPhoneIdentity?> resolveCurrentUserPhone({
    required String userId,
  }) async {
    final credentials = await _loadCredentials();
    if (credentials == null || credentials.userId != userId) return null;

    if (credentials.chatToken.isNotEmpty) {
      try {
        final remote = await _api.getUserFullInfo(
          userId: userId,
          chatToken: credentials.chatToken,
        );
        if (remote != null &&
            remote.userId == userId &&
            remote.phoneNumber.trim().isNotEmpty) {
          return AccountPhoneIdentity(
            areaCode: remote.areaCode.isNotEmpty
                ? remote.areaCode
                : credentials.areaCode,
            phoneNumber: remote.phoneNumber,
          );
        }
      } catch (e) {
        appLog.w('[AccountProfile] 获取账号完整资料失败，使用本地登录手机号: $e');
      }
    }

    if (credentials.phoneNumber.trim().isEmpty) return null;
    return AccountPhoneIdentity(
      areaCode: credentials.areaCode,
      phoneNumber: credentials.phoneNumber,
    );
  }
}
