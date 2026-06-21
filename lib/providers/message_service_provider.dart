import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/services/message_service_notifier.dart';

/// MessageServiceNotifier 的 Provider
final messageServiceProvider =
    StateNotifierProvider<MessageServiceNotifier, MessageServiceState>((ref) {
  return MessageServiceNotifier(ref);
});

/// MessageServiceNotifier 的便捷访问扩展
extension MessageServiceRef on WidgetRef {
  MessageServiceNotifier get messageService => read(messageServiceProvider.notifier);
  MessageServiceState get messageServiceState => read(messageServiceProvider);
}
