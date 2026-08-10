import '../../domain/models/friend_search_result.dart';
import '../services/friend_service.dart';
import '../services/im_client.dart';
import '../../src/rust/ffi/client.dart';
import '../../src/rust/http/friend.dart' show SearchFriendItem;

abstract class FriendSearchRepository {
  Future<List<FriendSearchResult>> search(String keyword);
  Future<void> sendFriendRequest(String userId, String reqMsg);
}

class FriendSearchRepositoryImpl implements FriendSearchRepository {
  FriendSearchRepositoryImpl({
    required FriendService friendService,
    required ImClient imClient,
  }) : _friendService = friendService,
       _imClient = imClient;

  final FriendService _friendService;
  final ImClient _imClient;

  @override
  Future<List<FriendSearchResult>> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      return const [];
    }
    final client = _requireClient();
    final results = await _friendService.searchFriends(
      client,
      keyword: keyword,
    );
    return results.map(mapSearchResult).toList(growable: false);
  }

  @override
  Future<void> sendFriendRequest(String userId, String reqMsg) async {
    final client = _requireClient();
    await _friendService.addFriend(client, userId: userId, reqMsg: reqMsg);
  }

  OpenImBridgeClient _requireClient() {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  static FriendSearchResult mapSearchResult(SearchFriendItem item) {
    return FriendSearchResult(
      userId: item.friendUserId,
      nickname: item.nickname,
      faceUrl: item.faceUrl,
      remark: item.remark,
      ex: item.ex,
      relationship: item.relationship,
      createdTime: _epochOrNull(item.createTime.toInt()),
    );
  }

  static DateTime? _epochOrNull(int epochMs) {
    if (epochMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}
