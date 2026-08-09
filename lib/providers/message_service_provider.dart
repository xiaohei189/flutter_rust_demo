import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/services/im_client.dart';
import 'package:flutter_rust_demo/ui/features/chat/view_models/message_service_notifier.dart';

/// MessageRepository Provider
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(imClient: ImClient.instance);
});

/// MessageServiceNotifier 的 Provider
final messageServiceProvider =
    StateNotifierProvider<MessageServiceNotifier, MessageServiceState>((ref) {
  return MessageServiceNotifier(repository: ref.watch(messageRepositoryProvider));
});

/// MessageServiceNotifier 的便捷访问扩展
extension MessageServiceRef on WidgetRef {
  MessageServiceNotifier get messageService => read(messageServiceProvider.notifier);
  MessageServiceState get messageServiceState => read(messageServiceProvider);
}
