import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:web_socket/web_socket.dart' show WebSocketConnectionClosed;

import 'package:fixleo/app/app.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/notifications/native_call_service.dart';
import 'package:fixleo/core/location/google_maps_bootstrap.dart';

Future<void> main() async {
  // socket_io_client's WebSocketTransport.doClose() calls `_ws?.close()`
  // without awaiting or guarding it — if the socket already closed itself
  // (server-initiated disconnect, or a stale socket torn down after a hot
  // restart) racing our own teardown, that close() rejects with
  // WebSocketConnectionClosed and nothing in the package catches it, so it
  // surfaces as an unhandled async exception that can crash the isolate.
  // The disconnect already happened either way, so this specific exception
  // is safe to drop; anything else still propagates normally.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeGoogleMapsRenderer();
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(fixleoFirebaseBackgroundHandler);
      // The headless CallKit background callback is implemented by the
      // Android side of flutter_callkit_incoming. Calling it on iOS throws a
      // MissingPluginException before runApp(), leaving the app on a blank
      // launch screen.
      if (Platform.isAndroid) {
        await FlutterCallkitIncoming.onBackgroundMessage(
          fixleoCallkitBackgroundHandler,
        );
      }
      // Restore any persisted login so the user stays signed in across restarts.
      await AuthSession.instance.load();
      // Restore the last chosen language before the first frame is built.
      await LocaleController.load();
      await NativeCallService.instance.initialize();
      runApp(const FixleoApp());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(warmUpGoogleMaps());
      });
    },
    (error, stack) {
      if (error is WebSocketConnectionClosed) return;
      debugPrint('Unhandled error: $error\n$stack');
    },
  );
}
