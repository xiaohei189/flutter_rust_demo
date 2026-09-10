import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/services/auth_api.dart' as auth_api;

void main() {
  late HttpServer server;
  late Duration originalTimeout;

  setUp(() async {
    originalTimeout = auth_api.debugAuthRequestTimeout;
    auth_api.debugAuthRequestTimeout = const Duration(milliseconds: 300);
    // 只接受连接、永不响应：模拟服务重启时"端口通但认证服务不干活"
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      // 故意不写响应
    });
    auth_api.debugAuthBaseUrlOverride = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    auth_api.debugAuthBaseUrlOverride = null;
    auth_api.debugAuthRequestTimeout = originalTimeout;
    await server.close(force: true);
  });

  test('密码登录在认证服务无响应时超时失败而不是永久挂起', () async {
    await expectLater(
      auth_api.loginAsync(
        areaCode: '+86',
        phoneNumber: '13800000000',
        password: '123456',
        platform: 5,
      ),
      throwsA(
        predicate(
          (Object e) => e.toString().contains('请求超时'),
          '超时错误应提示请求超时',
        ),
      ),
    );
  });

  test('验证码登录在认证服务无响应时超时失败', () async {
    await expectLater(
      auth_api.loginWithVerifyCode(
        areaCode: '+86',
        phoneNumber: '13800000000',
        verifyCode: '666666',
        platform: 5,
      ),
      throwsA(predicate((Object e) => e.toString().contains('请求超时'))),
    );
  });

  test('发送验证码在认证服务无响应时超时失败', () async {
    await expectLater(
      auth_api.sendVerificationCode(
        areaCode: '+86',
        phoneNumber: '13800000000',
        usedFor: auth_api.usedForLogin,
      ),
      throwsA(predicate((Object e) => e.toString().contains('请求超时'))),
    );
  });
}
