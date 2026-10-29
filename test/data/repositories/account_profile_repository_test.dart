import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_rust_demo/data/repositories/account_profile_repository.dart';
import 'package:flutter_rust_demo/data/services/account_profile_api.dart';
import 'package:flutter_rust_demo/data/services/login_storage.dart';

void main() {
  test('远程账号资料优先于本地登录手机号', () async {
    final api = AccountProfileApi(
      baseUrl: 'http://auth.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'errCode': 0,
            'data': {
              'users': [
                {
                  'userID': 'u1',
                  'areaCode': '+86',
                  'phoneNumber': '13900000000',
                },
              ],
            },
          }),
          200,
        ),
      ),
    );
    final repository = AccountProfileRepositoryImpl(
      api: api,
      loadCredentials: () async => const LoginCredentials(
        userId: 'u1',
        imToken: 'im-token',
        chatToken: 'chat-token',
        areaCode: '+1',
        phoneNumber: '13800000000',
      ),
    );

    final result = await repository.resolveCurrentUserPhone(userId: 'u1');

    expect(result?.areaCode, '+86');
    expect(result?.phoneNumber, '13900000000');
  });

  test('接口失败时回退到同账号本地登录手机号', () async {
    final api = AccountProfileApi(
      baseUrl: 'http://auth.test',
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    final repository = AccountProfileRepositoryImpl(
      api: api,
      loadCredentials: () async => const LoginCredentials(
        userId: 'u1',
        imToken: 'im-token',
        chatToken: 'expired-chat-token',
        areaCode: '+86',
        phoneNumber: '13800000000',
      ),
    );

    final result = await repository.resolveCurrentUserPhone(userId: 'u1');

    expect(result?.displayText, '+86 13800000000');
  });

  test('本地凭证不属于当前用户时不返回上一账号手机号', () async {
    var requestCount = 0;
    final api = AccountProfileApi(
      baseUrl: 'http://auth.test',
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );
    final repository = AccountProfileRepositoryImpl(
      api: api,
      loadCredentials: () async => const LoginCredentials(
        userId: 'u2',
        imToken: 'im-token',
        chatToken: 'chat-token',
        phoneNumber: '13800000000',
      ),
    );

    final result = await repository.resolveCurrentUserPhone(userId: 'u1');

    expect(result, isNull);
    expect(requestCount, 0);
  });
}
