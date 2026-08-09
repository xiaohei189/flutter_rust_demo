import '../../domain/models/group.dart';
import '../../services/group_service.dart';
import '../../services/im_client.dart';
import '../../src/rust/ffi/client.dart';
import '../../src/rust/model/group.dart' show GroupInfo;

abstract class GroupRepository {
  Future<List<Group>> loadGroups({int offset = 0, int count = 50});
}

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({
    required GroupService groupService,
    required ImClient imClient,
  }) : _groupService = groupService,
       _imClient = imClient;

  final GroupService _groupService;
  final ImClient _imClient;

  @override
  Future<List<Group>> loadGroups({int offset = 0, int count = 50}) async {
    final client = _requireClient();
    final groups = await _groupService.getJoinedGroupListPage(
      client,
      offset: offset,
      count: count,
    );
    return groups.map(_toDomain).toList(growable: false);
  }

  OpenImBridgeClient _requireClient() {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  Group _toDomain(GroupInfo item) {
    return Group(
      groupId: item.groupId,
      groupName: item.groupName,
      faceUrl: item.faceUrl,
      introduction: item.introduction,
      notification: item.notification,
      ownerUserId: item.ownerUserId,
      memberCount: item.memberCount,
      status: item.status,
      createdTime: _epochOrNull(item.createTime.toInt()),
    );
  }

  DateTime? _epochOrNull(int epochMs) {
    if (epochMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}
