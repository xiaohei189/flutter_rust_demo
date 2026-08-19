import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/chat_aux_repository.dart';
import '../data/services/file_open_service.dart';
import 'online_status_provider.dart';

final chatAuxRepositoryProvider = Provider<ChatAuxRepository>((ref) {
  return ChatAuxRepositoryImpl(
    onlineStatusService: ref.watch(onlineStatusServiceProvider),
    fileOpenService: FileOpenService.instance,
  );
});
