import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/services/message_service_notifier.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart';
import 'package:flutter_rust_demo/src/rust/im/model/conversation.dart';
import 'package:flutter_rust_demo/models/message.dart';
import 'package:flutter_rust_demo/src/rust/api/bridge_client.dart' show UserProfile, UserProfilePatch;

/// MessageServiceNotifier 的 Provider
final messageServiceProvider =
    StateNotifierProvider<MessageServiceNotifier, MessageServiceState>((ref) {
  return MessageServiceNotifier();
});

/// MessageServiceNotifier 的便捷访问扩展
extension MessageServiceRef on WidgetRef {
  MessageServiceNotifier get messageService => read(messageServiceProvider.notifier);
  MessageServiceState get messageServiceState => read(messageServiceProvider);
}
