import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../services/message_service.dart';

/// MessageService Provider
/// 全局单例，所有其他 Provider 都依赖它
final messageServiceProvider = Provider<MessageService>((ref) {
  return messageService;
});
