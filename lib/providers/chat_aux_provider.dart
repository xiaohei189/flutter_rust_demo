import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/chat_aux_repository.dart';
import '../services/file_open_service.dart';
import '../services/online_status_service.dart';

final chatAuxRepositoryProvider = Provider<ChatAuxRepository>((ref) {
  return ChatAuxRepositoryImpl(
    onlineStatusService: OnlineStatusService.instance,
    fileOpenService: FileOpenService.instance,
  );
});
