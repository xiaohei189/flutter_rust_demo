import 'package:flutter/foundation.dart';

class AppLifecycleService {
  static final AppLifecycleService instance = AppLifecycleService._internal();

  final ValueNotifier<bool> isBackground = ValueNotifier<bool>(false);

  AppLifecycleService._internal();

  /// 更新前后台状态；返回是否发生实际变化（调用方可据此跳过重复的 SDK 通知）
  bool update({required bool background}) {
    if (isBackground.value == background) return false;
    isBackground.value = background;
    return true;
  }
}
