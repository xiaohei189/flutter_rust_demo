import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前登录用户 ID，登录成功时同步写入，不依赖异步用户资料。
class CurrentUserNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setUserId(String userId) {
    state = userId;
  }

  void clear() {
    state = '';
  }
}

final currentUserIdProvider = NotifierProvider<CurrentUserNotifier, String>(
  CurrentUserNotifier.new,
);
