import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// 登录凭证本地存储，用于 splash 自动登录与登录页记住账号
class LoginStorage {
  static const _keyUserId = 'im_user_id';
  static const _keyImToken = 'im_token';
  static const _keyAreaCode = 'login_area_code';
  static const _keyPhoneNumber = 'login_phone_number';

  static Future<void> saveCredentials({
    required String userId,
    required String imToken,
    String areaCode = '+86',
    String phoneNumber = '',
  }) async {
    appLog.i('[LoginStorage] saveCredentials 开始');
    final prefs = await SharedPreferences.getInstance();
    appLog.i('[LoginStorage] SharedPreferences.getInstance 完成');
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyImToken, imToken);
    await prefs.setString(_keyAreaCode, areaCode);
    await prefs.setString(_keyPhoneNumber, phoneNumber);
    appLog.i('[LoginStorage] saveCredentials 完成');
  }

  static Future<LoginCredentials?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    final imToken = prefs.getString(_keyImToken);
    if (userId == null || userId.isEmpty || imToken == null || imToken.isEmpty) {
      return null;
    }
    return LoginCredentials(
      userId: userId,
      imToken: imToken,
      areaCode: prefs.getString(_keyAreaCode) ?? '+86',
      phoneNumber: prefs.getString(_keyPhoneNumber) ?? '',
    );
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyImToken);
    await prefs.remove(_keyAreaCode);
    await prefs.remove(_keyPhoneNumber);
  }
}

class LoginCredentials {
  final String userId;
  final String imToken;
  final String areaCode;
  final String phoneNumber;

  LoginCredentials({
    required this.userId,
    required this.imToken,
    this.areaCode = '+86',
    this.phoneNumber = '',
  });
}
