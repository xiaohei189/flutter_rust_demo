import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../ui/core/utils/app_logger.dart';
import '../ui/core/utils/host_config.dart';

/// 认证服务端基础 URL
String get kAuthBaseUrl => 'http://${getHostAddress()}:10008';

/// 账号服务中间件要求 header 带 operationID（与 openim-sdk-core cmd/sdk 一致）
String _nextOperationID() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256))
      .map((e) => e.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// 验证码用途：1=注册 2=重置密码 3=登录
const int usedForRegister = 1;
const int usedForResetPassword = 2;
const int usedForLogin = 3;

/// 登录结果（与 bridge_client LoginData 字段一致，用于验证码登录后保存）
class LoginResult {
  final String userId;
  final String imToken;
  final String chatToken;

  LoginResult({
    required this.userId,
    required this.imToken,
    required this.chatToken,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('登录响应无 data');
    return LoginResult(
      userId: data['userID'] as String? ?? '',
      imToken: data['imToken'] as String? ?? '',
      chatToken: data['chatToken'] as String? ?? '',
    );
  }
}

/// 注册结果（与 bridge_client RegisterData 字段一致）
class RegisterResult {
  final String userId;
  final String imToken;
  final String chatToken;

  RegisterResult({
    required this.userId,
    required this.imToken,
    required this.chatToken,
  });

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('注册响应无 data');
    return RegisterResult(
      userId: data['userID'] as String? ?? '',
      imToken: data['imToken'] as String? ?? '',
      chatToken: data['chatToken'] as String? ?? '',
    );
  }
}

/// 发送短信/邮箱验证码（与 openim-flutter-demo Apis.requestVerificationCode 对齐）
Future<void> sendVerificationCode({
  required String? areaCode,
  required String? phoneNumber,
  required int usedFor,
}) async {
  final url = Uri.parse('$kAuthBaseUrl/account/code/send');
  final resp = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'operationID': _nextOperationID(),
    },
    body: jsonEncode({
      'areaCode': areaCode,
      'phoneNumber': phoneNumber,
      'usedFor': usedFor,
    }),
  );
  if (resp.statusCode != 200) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>?;
    final errMsg = body?['errMsg'] ?? body?['errDtl'] ?? resp.body;
    throw Exception(errMsg);
  }
  final body = jsonDecode(resp.body) as Map<String, dynamic>?;
  if (body != null && body['errCode'] != 0) {
    throw Exception(body['errMsg']?.toString() ?? '发送验证码失败');
  }
}

/// 验证码登录（与 openim-flutter-demo Apis.login 传 verifyCode 对齐）
Future<LoginResult> loginWithVerifyCode({
  required String areaCode,
  required String phoneNumber,
  required String verifyCode,
  required int platform,
}) async {
  final url = Uri.parse('$kAuthBaseUrl/account/login');
  appLog.i('[AuthAPI] 验证码登录 HTTP 请求发出: $url');
  final resp = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'operationID': _nextOperationID(),
    },
    body: jsonEncode({
      'areaCode': areaCode,
      'phoneNumber': phoneNumber,
      'verifyCode': verifyCode.trim(),
      'platform': platform,
    }),
  );
  appLog.i('[AuthAPI] 验证码登录 HTTP 响应: statusCode=${resp.statusCode}');
  if (resp.statusCode != 200) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>?;
    final errMsg = body?['errMsg'] ?? body?['errDtl'] ?? resp.body;
    throw Exception(errMsg);
  }
  final json = jsonDecode(resp.body) as Map<String, dynamic>?;
  if (json == null) throw Exception('登录响应为空');
  if (json['errCode'] != 0) {
    throw Exception(json['errMsg']?.toString() ?? '登录失败');
  }
  return LoginResult.fromJson(json);
}

/// 验证码注册（与 openim-flutter-demo Apis.register 对齐）
Future<RegisterResult> registerWithVerifyCode({
  required String areaCode,
  required String phoneNumber,
  required String nickname,
  required String verifyCode,
  required int platform,
}) async {
  final url = Uri.parse('$kAuthBaseUrl/account/register');
  appLog.i('[AuthAPI] 验证码注册 HTTP 请求发出: $url');
  final resp = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'operationID': _nextOperationID(),
    },
    body: jsonEncode({
      'areaCode': areaCode,
      'phoneNumber': phoneNumber,
      'verifyCode': verifyCode.trim(),
      'platform': platform,
      'autoLogin': true,
      'user': {
        'nickname': nickname,
        'phoneNumber': phoneNumber,
        'areaCode': areaCode,
        'password': '',
      },
    }),
  );
  appLog.i('[AuthAPI] 验证码注册 HTTP 响应: statusCode=${resp.statusCode}');
  if (resp.statusCode != 200) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>?;
    final errMsg = body?['errMsg'] ?? body?['errDtl'] ?? resp.body;
    throw Exception(errMsg);
  }
  final json = jsonDecode(resp.body) as Map<String, dynamic>?;
  if (json == null) throw Exception('注册响应为空');
  if (json['errCode'] != 0) {
    throw Exception(json['errMsg']?.toString() ?? '注册失败');
  }
  return RegisterResult.fromJson(json);
}

/// 密码登录
Future<LoginResult> loginAsync({
  required String areaCode,
  required String phoneNumber,
  required String password,
  required int platform,
}) async {
  final url = Uri.parse('$kAuthBaseUrl/account/login');
  appLog.i('[AuthAPI] 密码登录 HTTP 请求发出: $url');
  final resp = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'operationID': _nextOperationID(),
    },
    body: jsonEncode({
      'areaCode': areaCode,
      'phoneNumber': phoneNumber,
      'password': password,
      'platform': platform,
    }),
  );
  appLog.i('[AuthAPI] 密码登录 HTTP 响应: statusCode=${resp.statusCode}');
  if (resp.statusCode != 200) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>?;
    final errMsg = body?['errMsg'] ?? body?['errDtl'] ?? resp.body;
    throw Exception(errMsg);
  }
  final json = jsonDecode(resp.body) as Map<String, dynamic>?;
  if (json == null) throw Exception('登录响应为空');
  if (json['errCode'] != 0) {
    throw Exception(json['errMsg']?.toString() ?? '登录失败');
  }
  return LoginResult.fromJson(json);
}
