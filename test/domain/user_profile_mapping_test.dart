import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/user_profile.dart';
import 'package:flutter_rust_demo/generated/rust/model/user.dart';

void main() {
  test('UserProfileMapping.fromUserInfo 保留核心字段', () {
    const raw = UserInfo(
      userId: 'u1',
      nickname: '张三',
      faceUrl: 'https://example.com/a.png',
      gender: 1,
      telephone: '13800000000',
      email: 'a@example.com',
      remark: '备注',
      globalRecvMsgOpt: 1,
    );

    final profile = UserProfileMapping.fromUserInfo(raw);

    expect(profile.userId, 'u1');
    expect(profile.nickname, '张三');
    expect(profile.faceUrl, 'https://example.com/a.png');
    expect(profile.remark, '备注');
    expect(profile.globalRecvMsgOpt, 1);
  });
}
