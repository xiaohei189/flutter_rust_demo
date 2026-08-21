import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/user_profile.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/user_profile_view_model.dart';

UserProfile _profile({String nickname = ' 张三 ', String remark = ''}) =>
    UserProfile(
      userId: 'u1',
      nickname: nickname,
      faceUrl: '',
      gender: 0,
      telephone: '',
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
  });

  group('UserProfileState ex 序列化', () {
    test('parseEx 兼容非法 JSON', () {
      expect(UserProfileState.parseEx(null), {'alias': '', 'signature': ''});
      expect(UserProfileState.parseEx('not-json'), {
        'alias': '',
        'signature': '',
      });
    });

    test('buildEx 保留已有字段并更新别名', () {
      final ex = UserProfileState.buildEx(
        currentEx: '{"alias":"旧名","signature":"旧签名"}',
        alias: '新名',
      );
      final decoded = UserProfileState.parseEx(ex);
      expect(decoded['alias'], '新名');
      expect(decoded['signature'], '旧签名');
    });
  });
}
