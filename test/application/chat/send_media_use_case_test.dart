import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/send_media_use_case.dart';

void main() {
  const useCase = SendMediaUseCase();

  test('发送目标缺失时返回 false 并写错误', () async {
    String? error;
    final ok = await useCase.send(
      readTarget: () => null,
      run: (_) async => true,
      readError: () => null,
      onError: (message) => error = message,
    );
    expect(ok, isFalse);
    expect(error, '会话信息异常');
  });

  test('发送失败时读取错误并写回', () async {
    String? error;
    final ok = await useCase.send(
      readTarget: () => 'u1',
      run: (_) async => false,
      readError: () => '网络错误',
      onError: (message) => error = message,
    );
    expect(ok, isFalse);
    expect(error, '网络错误');
  });

  test('发送成功返回 true 且不写错误', () async {
    String? error;
    var ran = false;
    final ok = await useCase.send(
      readTarget: () => 'u1',
      run: (target) async {
        ran = target == 'u1';
        return true;
      },
      readError: () => null,
      onError: (message) => error = message,
    );
    expect(ok, isTrue);
    expect(ran, isTrue);
    expect(error, isNull);
  });
}
