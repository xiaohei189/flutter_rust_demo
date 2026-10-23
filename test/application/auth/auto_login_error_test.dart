import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/auth/auto_login_error.dart';

void main() {
  test('连接被拒/超时不清除凭证', () {
    expect(
      shouldClearCredentialsOnAutoLoginFailure(
        'AnyhowException(连接错误: WebSocket connect failed: IO error: Connection refused (os error 111))',
      ),
      isFalse,
    );
    expect(
      shouldClearCredentialsOnAutoLoginFailure('AnyhowException(超时: rpc timeout)'),
      isFalse,
    );
  });

  test('明确 token 失效才清除凭证', () {
    expect(
      shouldClearCredentialsOnAutoLoginFailure('401 Unauthorized'),
      isTrue,
    );
    expect(
      shouldClearCredentialsOnAutoLoginFailure('AnyhowException(token expired)'),
      isTrue,
    );
  });

  test('未知错误保守保留凭证', () {
    expect(
      shouldClearCredentialsOnAutoLoginFailure('unexpected platform error'),
      isFalse,
    );
  });
}
