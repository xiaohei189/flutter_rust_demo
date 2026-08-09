import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/repositories/friend_application_repository.dart';
import 'package:flutter_rust_demo/data/repositories/friend_repository.dart';
import 'package:flutter_rust_demo/data/repositories/friend_search_repository.dart';
import 'package:flutter_rust_demo/src/rust/http/friend.dart';
import 'package:flutter_rust_demo/src/rust/model/friend.dart';

void main() {
  group('FriendRepository mapping', () {
    test('mapFriendInfo 保留核心字段并转换时间', () {
      final friend = FriendRepositoryImpl.mapFriendInfo(
        const FriendInfo(
          userId: 'u1',
          nickname: '张三',
          faceUrl: 'https://example.com/a.png',
          gender: 1,
          remark: '阿三',
          createTime: 1700000000000,
          addSource: 'search',
          ex: '{}',
        ),
      );

      expect(friend.userId, 'u1');
      expect(friend.nickname, '张三');
      expect(friend.faceUrl, 'https://example.com/a.png');
      expect(friend.remark, '阿三');
      expect(friend.createdTime, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('mapSearchFriendItem 映射搜索结果', () {
      final result = FriendSearchRepositoryImpl.mapSearchResult(
        const SearchFriendItem(
          friendUserId: 'u2',
          nickname: '李四',
          faceUrl: '',
          remark: '备注',
          ex: '',
          createTime: 0,
          relationship: 2,
        ),
      );

      expect(result.userId, 'u2');
      expect(result.nickname, '李四');
      expect(result.relationship, 2);
      expect(result.createdTime, isNull);
    });

    test('mapApplication 映射好友申请', () {
      final application = FriendApplicationRepositoryImpl.mapApplication(
        const FriendApplyInfo(
          userId: 'u3',
          nickname: '王五',
          faceUrl: '',
          gender: 2,
          createTime: 0,
          addSource: 1,
          ex: '',
          reqMsg: '你好',
          handleResult: 0,
        ),
      );

      expect(application.userId, 'u3');
      expect(application.reqMsg, '你好');
      expect(application.handleResult, 0);
    });
  });
}
