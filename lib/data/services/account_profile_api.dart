import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/host_config.dart';

/// 账号服务完整用户资料。
class AccountFullUserInfo {
  const AccountFullUserInfo({
    required this.userId,
    required this.areaCode,
    required this.phoneNumber,
  });

  final String userId;
  final String areaCode;
  final String phoneNumber;

  factory AccountFullUserInfo.fromJson(Map<String, dynamic> json) {
    return AccountFullUserInfo(
      userId: json['userID'] as String? ?? '',
      areaCode: json['areaCode'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
    );
  }
}

/// OpenIM 账号服务完整资料接口。
///
/// 登录手机号位于账号服务的 `phoneNumber` 字段，不在核心 IM 的
/// `/user/get_users_info.telephone` 中。
class AccountProfileApi {
  AccountProfileApi({
    required http.Client client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client,
       _baseUrl = baseUrl ?? 'http://${getHostAddress()}:10008';

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  Future<AccountFullUserInfo?> getUserFullInfo({
    required String userId,
    required String chatToken,
  }) async {
    if (userId.trim().isEmpty || chatToken.trim().isEmpty) return null;

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/user/find/full'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'operationID': _newOperationId(),
            'token': chatToken,
          },
          body: jsonEncode({
            'pagination': {'pageNumber': 0, 'showNumber': 10},
            'userIDs': [userId],
            'platform': 5,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('获取账号资料失败，HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('账号资料响应格式错误');
    }
    final errCode = decoded['errCode'] as int? ?? -1;
    if (errCode != 0) {
      throw Exception(decoded['errMsg'] as String? ?? '获取账号资料失败');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return null;
    final users = data['users'];
    if (users is! List || users.isEmpty) return null;

    final first = users.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('账号资料 users 格式错误');
    }
    return AccountFullUserInfo.fromJson(first);
  }

  static String _newOperationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
