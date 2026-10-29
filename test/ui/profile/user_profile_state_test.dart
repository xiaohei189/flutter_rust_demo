import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/user_profile.dart';
import 'package:flutter_rust_demo/domain/models/user_profile_remark.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/user_profile_view_model.dart';

UserProfile _profile({
  String nickname = ' 张三 ',
  String remark = '',
  String telephone = '',
  String areaCode = '',
  String phoneNumber = '',
}) => UserProfile(
  userId: 'u1',
  nickname: nickname,
  faceUrl: '',
  gender: 0,
  telephone: telephone,
  areaCode: areaCode,
  phoneNumber: phoneNumber,
  email: '',
  remark: remark,
  globalRecvMsgOpt: 0,
);

void main() {
  group('UserProfileState.fromServerProfile', () {
    test('解析别名/签名并保留本地头像路径', () {
      final state = UserProfileState.fromServerProfile(
        _profile(remark: '{"alias":"小张","signature":"你好"}'),
        localAvatarPath: '/tmp/avatar.jpg',
      );

      expect(state.nickname, '张三');
      expect(state.alias, '小张');
      expect(state.signature, '你好');
      expect(state.localAvatarPath, '/tmp/avatar.jpg');
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('无 ex 时别名/签名为空', () {
      final state = UserProfileState.fromServerProfile(_profile());
      expect(state.alias, '');
      expect(state.signature, '');
    });

    test('手机号优先展示账号服务字段并拼接区号', () {
      final state = UserProfileState.fromServerProfile(
        _profile(
          areaCode: '+86',
          phoneNumber: '13800000000',
          telephone: '010-12345678',
        ),
      );

      expect(state.displayPhoneNumber, '+86 13800000000');
    });

    test('没有账号手机号时兼容旧 telephone 字段', () {
      final state = UserProfileState.fromServerProfile(
        _profile(telephone: '010-12345678'),
      );

      expect(state.displayPhoneNumber, '010-12345678');
    });
  });

  group('UserProfileRemark ex 序列化', () {
    test('parse 兼容非法 JSON', () {
      final empty = UserProfileRemark.parse(null);
      expect(empty.alias, '');
      expect(empty.signature, '');
      final invalid = UserProfileRemark.parse('not-json');
      expect(invalid.alias, '');
      expect(invalid.signature, '');
    });

    test('buildEx 保留已有字段并更新别名', () {
      final ex = UserProfileRemark.buildEx(
        currentEx: '{"alias":"旧名","signature":"旧签名"}',
        alias: '新名',
      );
      final decoded = UserProfileRemark.parse(ex);
      expect(decoded.alias, '新名');
      expect(decoded.signature, '旧签名');
    });
  });
}
