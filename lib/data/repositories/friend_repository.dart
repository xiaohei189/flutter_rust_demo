import '../../domain/models/friend.dart';
import '../../services/friend_service.dart';
import '../../services/im_client.dart';
import '../../src/rust/ffi/client.dart';
import '../../src/rust/http/friend.dart' show SearchFriendItem;
import '../../src/rust/model/friend.dart' show FriendInfo;

abstract class FriendRepository {
  Future<List<Friend>> loadFriends();
  Future<List<Friend>> searchFriends(String keyword);
  Future<void> deleteFriend(String userId);
  Future<void> updateFriends(String userId, {String? remark});
  Future<bool> isFriend(String userId);
}

class FriendRepositoryImpl implements FriendRepository {
  FriendRepositoryImpl({
    required FriendService friendService,
    required ImClient imClient,
  }) : _friendService = friendService,
       _imClient = imClient;

  final FriendService _friendService;
  final ImClient _imClient;

  @override
  Future<List<Friend>> loadFriends() async {
    final client = _requireClient();
    final friends = await _friendService.getFriendList(client);
    return friends.map(mapFriendInfo).toList(growable: false);
  }

  @override
  Future<List<Friend>> searchFriends(String keyword) async {
    if (keyword.trim().isEmpty) {
      return loadFriends();
    }
    final client = _requireClient();
    final results = await _friendService.searchFriends(
      client,
      keyword: keyword,
    );
    return results.map(mapSearchFriendItem).toList(growable: false);
  }

  @override
  Future<void> deleteFriend(String userId) async {
    final client = _requireClient();
    await _friendService.deleteFriend(client, userId: userId);
  }

  @override
  Future<void> updateFriends(String userId, {String? remark}) async {
    final client = _requireClient();
    await _friendService.updateFriends(
      client,
      friendUserIds: [userId],
      remark: remark,
    );
  }

  @override
  Future<bool> isFriend(String userId) async {
    final client = _requireClient();
    return _friendService.isFriend(client, userId: userId);
  }

  OpenImBridgeClient _requireClient() {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  static Friend mapFriendInfo(FriendInfo item) {
    return Friend(
      userId: item.userId,
      nickname: item.nickname,
      faceUrl: item.faceUrl,
      gender: item.gender,
      remark: item.remark,
      addSource: item.addSource,
      ex: item.ex,
      createdTime: _epochOrNull(item.createTime.toInt()),
    );
  }

  static Friend mapSearchFriendItem(SearchFriendItem item) {
    return Friend(
      userId: item.friendUserId,
      nickname: item.nickname,
      faceUrl: item.faceUrl,
      gender: 0,
      remark: item.remark,
      addSource: '',
      ex: item.ex,
      createdTime: _epochOrNull(item.createTime.toInt()),
    );
  }

  static DateTime? _epochOrNull(int epochMs) {
    if (epochMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}
