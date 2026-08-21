import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/providers/im_providers.dart';

import '../../../application/chat/message_service_notifier.dart';
import '../../../application/chat/message_service_state.dart';

export '../../../application/chat/message_service_state.dart';

/// MessageRepository Provider
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(imClient: ref.watch(imClientProvider));
});

/// MessageServiceNotifier 的 Provider
final messageServiceProvider =
    NotifierProvider<MessageServiceNotifier, MessageServiceState>(
      MessageServiceNotifier.new,
    );

/// MessageServiceNotifier 的便捷访问扩展
extension MessageServiceRef on WidgetRef {
  MessageServiceNotifier get messageService =>
      read(messageServiceProvider.notifier);
  MessageServiceState get messageServiceState => read(messageServiceProvider);
}
