import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_theme.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/notifications/native_call_service.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/features/calls/presentation/call_screen.dart';
import 'package:fixleo/features/splash/presentation/splash_screen.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';

/// App-wide navigator key — lets non-widget code (e.g. the call service) push
/// screens from anywhere, so an incoming voice call can ring on ANY screen, not
/// only when a chat is open.
final GlobalKey<NavigatorState> fixleoNavigatorKey =
    GlobalKey<NavigatorState>();

/// Present the full-screen call UI for an incoming call, from anywhere.
void showIncomingCallUi() {
  fixleoNavigatorKey.currentState?.push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CallScreen(),
    ),
  );
}

class FixleoApp extends StatefulWidget {
  const FixleoApp({super.key});

  @override
  State<FixleoApp> createState() => _FixleoAppState();
}

class _FixleoAppState extends State<FixleoApp> with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.expirationEvents.addListener(_onSessionExpired);
    AuthSession.instance.sessionEvents.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativeCallService.instance.bindCallUi(showIncomingCallUi);
      AppPresenceService.instance.setForeground(_foreground);
      CallService.instance.syncForCurrentSession(
        onIncoming: NativeCallService.instance.showIncomingFromSocket,
      );
    });
  }

  @override
  void dispose() {
    AppPresenceService.instance.disconnect();
    CallService.instance.disconnect();
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.expirationEvents.removeListener(_onSessionExpired);
    AuthSession.instance.sessionEvents.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    AppPresenceService.instance.setForeground(_foreground);
    if (_foreground) {
      CallService.instance.syncForCurrentSession(
        onIncoming: NativeCallService.instance.showIncomingFromSocket,
      );
      CallService.instance.retryPendingRecordings();
    }
  }

  void _onSessionChanged() {
    // Login, logout and role/account replacement must update call signalling
    // immediately. In particular, logout can never leave the old JWT socket
    // connected in the background.
    CallService.instance.syncForCurrentSession(
      onIncoming: NativeCallService.instance.showIncomingFromSocket,
    );
    if (_foreground) {
      AppPresenceService.instance.connectForCurrentSession();
    } else {
      AppPresenceService.instance.disconnect();
    }
  }

  void _onSessionExpired() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fixleoNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IntroScreen()),
        (_) => false,
      );
    });
  }

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
          locale: Locale(lang.name),
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}
