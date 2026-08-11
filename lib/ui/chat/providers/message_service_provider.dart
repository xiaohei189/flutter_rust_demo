import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import '../view_models/message_service_notifier.dart';
import '../view_models/message_service_state.dart';
export '../view_models/message_service_state.dart';

/// MessageRepository Provider
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(imClient: ImClient.instance);
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
