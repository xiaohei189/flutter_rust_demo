import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_rust_demo/data/services/account_profile_api.dart';

void main() {
  test('账号完整资料接口解析 phoneNumber 和 areaCode', () async {
    late http.Request captured;
    final api = AccountProfileApi(
      baseUrl: 'http://auth.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'errCode': 0,
            'errMsg': '',
            'data': {
              'users': [
                {
                  'userID': 'u1',
                  'areaCode': '+86',
                  'phoneNumber': '13800000000',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final result = await api.getUserFullInfo(
      userId: 'u1',
      chatToken: 'chat-token',
    );

    expect(captured.url.toString(), 'http://auth.test/user/find/full');
    expect(captured.headers['token'], 'chat-token');
    expect(captured.headers['operationID'], isNotEmpty);
    expect(jsonDecode(captured.body), containsPair('userIDs', ['u1']));
    expect(result?.userId, 'u1');
    expect(result?.areaCode, '+86');
    expect(result?.phoneNumber, '13800000000');
  });

  test('账号完整资料接口对 HTTP 错误抛出异常', () async {
    final api = AccountProfileApi(
      baseUrl: 'http://auth.test',
      client: MockClient((_) async => http.Response('unauthorized', 401)),
    );

    await expectLater(
      api.getUserFullInfo(userId: 'u1', chatToken: 'bad-token'),
      throwsA(predicate((Object e) => e.toString().contains('HTTP 401'))),
    );
  });
}
