import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_theme.dart';
import 'package:fixleo/features/calls/presentation/call_screen.dart';
import 'package:fixleo/features/splash/presentation/splash_screen.dart';

/// App-wide navigator key — lets non-widget code (e.g. the call service) push
/// screens from anywhere, so an incoming voice call can ring on ANY screen, not
/// only when a chat is open.
final GlobalKey<NavigatorState> fixleoNavigatorKey = GlobalKey<NavigatorState>();

/// Present the full-screen call UI for an incoming call, from anywhere.
void showIncomingCallUi() {
  fixleoNavigatorKey.currentState?.push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CallScreen()),
  );
}

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
          navigatorKey: fixleoNavigatorKey,
          home: const SplashScreen(),
        );
      },
    );
  }
}
