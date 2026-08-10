import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/chat_aux_repository.dart';
import '../data/services/file_open_service.dart';
import '../data/services/online_status_service.dart';

final chatAuxRepositoryProvider = Provider<ChatAuxRepository>((ref) {
  return ChatAuxRepositoryImpl(
    onlineStatusService: OnlineStatusService.instance,
    fileOpenService: FileOpenService.instance,
  );
});
