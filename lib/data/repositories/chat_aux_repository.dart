import '../../services/file_open_service.dart';
import '../../services/online_status_service.dart';

abstract class ChatAuxRepository {
  Future<void> subscribeOnlineStatus(List<String> userIds);
  Future<void> unsubscribeOnlineStatus(List<String> userIds);
  Future<bool> openFile({required String source, required String fileName});
}

class ChatAuxRepositoryImpl implements ChatAuxRepository {
  ChatAuxRepositoryImpl({
    required OnlineStatusService onlineStatusService,
    required FileOpenService fileOpenService,
  })  : _onlineStatusService = onlineStatusService,
        _fileOpenService = fileOpenService;

  final OnlineStatusService _onlineStatusService;
  final FileOpenService _fileOpenService;

  @override
  Future<void> subscribeOnlineStatus(List<String> userIds) {
    return _onlineStatusService.subscribe(userIds);
  }

  @override
  Future<void> unsubscribeOnlineStatus(List<String> userIds) {
    return _onlineStatusService.unsubscribe(userIds);
  }

  @override
  Future<bool> openFile({required String source, required String fileName}) {
    return _fileOpenService.open(source: source, fileName: fileName);
  }
}
