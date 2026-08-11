import '../../domain/models/friend_application.dart';
import '../services/friend_service.dart';
import '../services/im_client.dart';
import '../../generated/rust/ffi/client.dart';
import '../../generated/rust/http/friend.dart' show FriendApplyInfo;

abstract class FriendApplicationRepository {
  Future<({List<FriendApplication> received, List<FriendApplication> sent})>
  loadApplications();

  Future<void> accept(String userId, {String? handleMsg});
  Future<void> refuse(String userId, {String? handleMsg});
}

class FriendApplicationRepositoryImpl implements FriendApplicationRepository {
  FriendApplicationRepositoryImpl({
    required FriendService friendService,
    required ImClient imClient,
  }) : _friendService = friendService,
       _imClient = imClient;

  final FriendService _friendService;
  final ImClient _imClient;

  @override
  Future<({List<FriendApplication> received, List<FriendApplication> sent})>
  loadApplications() async {
    final client = _requireClient();
    final received = await _friendService.getFriendApplyList(client);
    final sent = await _friendService.getFriendApplyListAsApplicant(client);
    return (
      received: received.map(mapApplication).toList(growable: false),
      sent: sent.map(mapApplication).toList(growable: false),
    );
  }

  @override
  Future<void> accept(String userId, {String? handleMsg}) async {
    final client = _requireClient();
    await _friendService.acceptFriendApplication(
      client,
      userId: userId,
      handleMsg: handleMsg,
    );
  }

  @override
  Future<void> refuse(String userId, {String? handleMsg}) async {
    final client = _requireClient();
    await _friendService.refuseFriendApplication(
      client,
      userId: userId,
      handleMsg: handleMsg,
    );
  }

  OpenImBridgeClient _requireClient() {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  static FriendApplication mapApplication(FriendApplyInfo item) {
    return FriendApplication(
      userId: item.userId,
      nickname: item.nickname,
      faceUrl: item.faceUrl,
      gender: item.gender,
      addSource: item.addSource,
      ex: item.ex,
      handleResult: item.handleResult,
      reqMsg: item.reqMsg,
      handleMsg: item.handleMsg,
      createdTime: _epochOrNull(item.createTime.toInt()),
    );
  }

  static DateTime? _epochOrNull(int epochMs) {
    if (epochMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}
