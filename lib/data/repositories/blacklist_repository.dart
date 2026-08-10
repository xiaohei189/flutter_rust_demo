import '../../domain/models/blacklist_user.dart';
import '../services/friend_service.dart';
import '../services/im_client.dart';
import '../services/user_service.dart';
import '../../src/rust/ffi/client.dart';

abstract class BlacklistRepository {
  Future<List<BlacklistUser>> load();
  Future<void> add(String userId);
  Future<void> remove(String userId);
}

class BlacklistRepositoryImpl implements BlacklistRepository {
  BlacklistRepositoryImpl({
    required FriendService friendService,
    required UserService userService,
    required ImClient imClient,
  }) : _friendService = friendService,
       _userService = userService,
       _imClient = imClient;

  final FriendService _friendService;
  final UserService _userService;
  final ImClient _imClient;

  @override
  Future<List<BlacklistUser>> load() async {
    final client = _requireClient();
    final userIds = await _friendService.getBlackList(client);
    await _userService.preloadUserProfiles(userIds);
    final profiles = _userService.getUserProfiles(userIds);
    final profileById = {for (final p in profiles) p.userId: p};

    return userIds
        .map((userId) {
          final profile = profileById[userId];
          return BlacklistUser(
            userId: userId,
            nickname: profile?.nickname.isNotEmpty == true
                ? profile!.nickname
                : userId,
            faceUrl: profile?.faceUrl ?? '',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> add(String userId) async {
    final client = _requireClient();
    await _friendService.addBlack(client, userId: userId);
  }

  @override
  Future<void> remove(String userId) async {
    final client = _requireClient();
    await _friendService.removeBlack(client, userId: userId);
  }

  OpenImBridgeClient _requireClient() {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }
}
