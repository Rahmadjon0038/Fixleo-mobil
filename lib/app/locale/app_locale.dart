import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the app can switch between.
enum AppLanguage { uz, ru, en }

/// Global, app-wide selected language. Widgets listen to [language] (via a
/// [ValueListenableBuilder] or [AnimatedBuilder]) and rebuild when it changes,
/// so picking a language in the profile updates the UI live.
class LocaleController {
  LocaleController._();

  static const _kLanguage = 'app_language';

  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(AppLanguage.uz);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLanguage);
    for (final lang in AppLanguage.values) {
      if (lang.name == raw) {
        language.value = lang;
        break;
      }
    }
  }

  static void set(AppLanguage lang) {
    language.value = lang;
    unawaited(_save(lang));
  }

  static Future<void> _save(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, lang.name);
  }
}

/// Tiny inline translator: returns the string for the current [lang].
/// [en] is optional — when omitted, English falls back to the Uzbek text.
/// Keeps mock screens simple without a full localization setup.
String tr(AppLanguage lang, String uz, String ru, [String? en]) =>
    switch (lang) {
      AppLanguage.uz => uz,
      AppLanguage.ru => ru,
      AppLanguage.en => en ?? uz,
    };

/// Human-friendly duration for wait/retry messages: 354 seconds becomes
/// "5 daqiqa 54 soniya" / "5 мин 54 сек" / "5 min 54 sec".
String formatWait(AppLanguage lang, int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return tr(lang, '$s soniya', '$s сек', '$s sec');
  if (s == 0) return tr(lang, '$m daqiqa', '$m мин', '$m min');
  return tr(lang, '$m daqiqa $s soniya', '$m мин $s сек', '$m min $s sec');
}
