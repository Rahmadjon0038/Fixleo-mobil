import 'package:flutter/foundation.dart';

/// Languages the app can switch between.
enum AppLanguage { uz, ru, en }

/// Global, app-wide selected language. Widgets listen to [language] (via a
/// [ValueListenableBuilder] or [AnimatedBuilder]) and rebuild when it changes,
/// so picking a language in the profile updates the UI live.
class LocaleController {
  LocaleController._();

  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(AppLanguage.uz);

  static void set(AppLanguage lang) => language.value = lang;
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
