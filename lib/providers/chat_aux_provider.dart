import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/chat_aux_repository.dart';
import 'im_providers.dart';
import 'online_status_provider.dart';

final chatAuxRepositoryProvider = Provider<ChatAuxRepository>((ref) {
  return ChatAuxRepositoryImpl(
    onlineStatusService: ref.watch(onlineStatusServiceProvider),
    fileOpenService: ref.watch(fileOpenServiceProvider),
  );
});
