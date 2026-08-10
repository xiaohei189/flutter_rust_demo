import 'package:flutter/foundation.dart';

class AppLifecycleService {
  static final AppLifecycleService instance = AppLifecycleService._internal();

  final ValueNotifier<bool> isBackground = ValueNotifier<bool>(false);

  AppLifecycleService._internal();

  void update({required bool background}) {
    if (isBackground.value == background) return;
    isBackground.value = background;
  }
}
