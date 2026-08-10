import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static final LocaleService instance = LocaleService._internal();

  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  static const _localeKey = 'app_locale';

  LocaleService._internal();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == 'en') {
      locale.value = const Locale('en');
    } else {
      locale.value = const Locale('zh');
    }
  }

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
    locale.value = code == 'en' ? const Locale('en') : const Locale('zh');
  }
}
