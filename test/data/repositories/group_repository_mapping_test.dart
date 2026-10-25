import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/repositories/group_repository.dart';
import 'package:flutter_rust_demo/generated/rust/infra/http/group.dart';
import 'package:flutter_rust_demo/generated/rust/domain/model/group.dart';

void main() {
  group('GroupRepository mapping', () {
    test('mapGroup 保留群组字段', () {
      final group = GroupRepositoryImpl.mapGroup(
        const GroupInfo(
          groupId: 'g1',
          groupName: '测试群',
          faceUrl: '',
          introduction: '简介',
          notification: '公告',
          ownerUserId: 'u1',
          createTime: 1700000000000,
          memberCount: 3,
          status: 0,
        ),
      );

      expect(group.groupId, 'g1');
      expect(group.groupName, '测试群');
      expect(group.memberCount, 3);
      expect(
        group.createdTime,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('mapMember 映射群成员', () {
      final member = GroupRepositoryImpl.mapMember(
        const GroupMember(
          groupId: 'g1',
          userId: 'u1',
          nickname: '张三',
          faceUrl: '',
          roleLevel: 3,
          joinTime: 0,
          joinSource: '',
          muteEndTime: 0,
        ),
      );

      expect(member.groupId, 'g1');
      expect(member.userId, 'u1');
      expect(member.roleLevel, 3);
      expect(member.joinTime, isNull);
      expect(member.muteEndTime, isNull, reason: '0 表示未禁言，应映射为 null');
    });

    test('mapMember 保留禁言结束时间', () {
      final member = GroupRepositoryImpl.mapMember(
        const GroupMember(
          groupId: 'g1',
          userId: 'u1',
          nickname: '张三',
          faceUrl: '',
          roleLevel: 1,
          joinTime: 0,
          joinSource: '',
          muteEndTime: 1792922045375,
        ),
      );

      expect(
        member.muteEndTime,
        DateTime.fromMillisecondsSinceEpoch(1792922045375),
      );
    });

    test('mapApplication 映射群申请', () {
      final application = GroupRepositoryImpl.mapApplication(
        const GroupApplyInfo(
          groupId: 'g1',
          userId: 'u2',
          nickname: '李四',
          faceUrl: '',
          reason: '想加入',
          handleResult: 1,
        ),
      );

      expect(application.groupId, 'g1');
      expect(application.reason, '想加入');
      expect(application.handleResult, 1);
    });
  });
}
