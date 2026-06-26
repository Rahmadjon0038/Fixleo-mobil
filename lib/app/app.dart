import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_theme.dart';
import 'package:fixleo/features/splash/presentation/splash_screen.dart';

class FixleoApp extends StatelessWidget {
  const FixleoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes, so every screen that
    // reads LocaleController.language re-translates live.
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.language,
      builder: (context, lang, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Fixleo',
          theme: AppTheme.light(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
