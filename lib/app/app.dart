import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_theme.dart';
import 'package:fixleo/app/widgets/push_notification_banner.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/notifications/native_call_service.dart';
import 'package:fixleo/core/notifications/push_delivery_policy.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/features/calls/presentation/call_screen.dart';
import 'package:fixleo/features/notifications/presentation/notifications_screen.dart';
import 'package:fixleo/features/notifications/presentation/notification_destination.dart';
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
  OverlayEntry? _notificationOverlay;
  bool _navigationReady = false;
  AppPushNotification? _pendingNotification;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.expirationEvents.addListener(_onSessionExpired);
    AuthSession.instance.sessionEvents.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativeCallService.instance.bindCallUi(showIncomingCallUi);
      NativeCallService.instance.bindNotificationUi(
        show: _showPushBanner,
        open: _openPushNotification,
      );
      AppPresenceService.instance.setForeground(_foreground);
      CallService.instance.syncForCurrentSession(
        onIncoming: NativeCallService.instance.showIncomingFromSocket,
      );
    });
  }

  @override
  void dispose() {
    _notificationOverlay?.remove();
    _notificationOverlay?.dispose();
    NativeCallService.instance.unbindNotificationUi();
    AppPresenceService.instance.disconnect();
    CallService.instance.disconnect();
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.expirationEvents.removeListener(_onSessionExpired);
    AuthSession.instance.sessionEvents.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _showPushBanner(AppPushNotification notification) {
    if (!mounted || !_foreground || !AuthSession.instance.isLoggedIn) return;
    final overlay = fixleoNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    final previous = _notificationOverlay;
    if (previous != null) _dismissPushBanner(previous);
    final epoch = AuthSession.instance.sessionEvents.value;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 8,
        left: 12,
        right: 12,
        child: PushNotificationBanner(
          title: notification.title,
          body: notification.body,
          onOpen: () {
            if (epoch == AuthSession.instance.sessionEvents.value) {
              _openPushNotification(notification);
            }
          },
          onDismiss: () => _dismissPushBanner(entry),
        ),
      ),
    );
    _notificationOverlay = entry;
    overlay.insert(entry);
  }

  void _dismissPushBanner(OverlayEntry entry) {
    if (!identical(_notificationOverlay, entry)) return;
    _notificationOverlay = null;
    entry.remove();
    entry.dispose();
  }

  void _onNavigationReady() {
    if (!mounted) return;
    _navigationReady = true;
    final pending = _pendingNotification;
    _pendingNotification = null;
    if (pending != null) _openPushNotification(pending);
  }

  void _openPushNotification(AppPushNotification notification) {
    if (!mounted) return;
    final session = AuthSession.instance;
    if (!session.isLoggedIn ||
        !PushDeliveryPolicy().belongsTo(
          notification.data,
          session.role?.name ?? '',
          session.subjectId,
        )) {
      return;
    }
    if (!_navigationReady) {
      _pendingNotification = notification;
      return;
    }
    final epoch = AuthSession.instance.sessionEvents.value;
    final role = AuthSession.instance.role;
    if (role != AuthRole.client && role != AuthRole.master) return;
    final kind = role!.name;
    final destination = notificationDestination(
      kind: kind,
      type: notification.data['type']?.toString() ?? '',
      data: notification.data,
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => destination ?? NotificationsScreen(kind: kind),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != AuthSession.instance.sessionEvents.value) return;
      fixleoNavigatorKey.currentState?.push(route);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    NativeCallService.instance.setForeground(_foreground);
    if (!_foreground && _notificationOverlay != null) {
      _dismissPushBanner(_notificationOverlay!);
    }
    AppPresenceService.instance.setForeground(_foreground);
    if (_foreground) {
      CallService.instance.syncForCurrentSession(
        onIncoming: NativeCallService.instance.showIncomingFromSocket,
      );
      CallService.instance.retryPendingRecordings();
    }
  }

  void _onSessionChanged() {
    _pendingNotification = null;
    if (_notificationOverlay != null) _dismissPushBanner(_notificationOverlay!);
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
          home: SplashScreen(onReady: _onNavigationReady),
        );
      },
    );
  }
}
