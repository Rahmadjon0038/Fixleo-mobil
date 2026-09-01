import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/realtime/call_service.dart';

const _pendingBackgroundActionKey = 'pending_native_call_action';
const _nativeCallsChannelName = 'com.fixleo.app/native_calls';

/// FCM invokes this in a separate isolate when Android is backgrounded/killed.
@pragma('vm:entry-point')
Future<void> fixleoFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await AuthSession.instance.load();
  // A background message runs in a fresh isolate, so the in-memory locale is
  // back at its default value. Restore the user's persisted language before
  // constructing native CallKit labels (accept, decline, missed call, etc.).
  await LocaleController.load();
  if (!NativeCallService.hasCallableSession) return;
  await NativeCallService.handlePushData(message.data);
}

/// Android call buttons can also be dispatched to a headless Flutter isolate.
/// Persist the action first; decline is additionally finalized through REST so
/// the caller does not keep ringing while the UI process is absent.
@pragma('vm:entry-point')
Future<void> fixleoCallkitBackgroundHandler(CallEvent event) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSession.instance.load();
  final payload = NativeCallService.eventPayload(event);
  if (payload == null) return;
  await NativeCallService.stopAndroidVibrationFallback();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingBackgroundActionKey, jsonEncode(payload));
  if (payload['nativeAction'] == 'decline') {
    await NativeCallService.rejectFromPayload(payload);
  }
}

/// Bridges FCM/PushKit + Android full-screen intent + iOS CallKit to the
/// existing Socket.IO/WebRTC call service.
class NativeCallService {
  NativeCallService._();

  static final NativeCallService instance = NativeCallService._();
  static const MethodChannel _nativeChannel = MethodChannel(
    _nativeCallsChannelName,
  );

  final AuthSession _session = AuthSession.instance;
  final Set<String> _handledActions = <String>{};
  StreamSubscription<String>? _tokenRefreshSubscription;
  VoidCallback? _openCallUi;
  bool _initialized = false;
  bool _permissionsRequested = false;
  bool _uiPending = false;

  static bool get hasCallableSession {
    final role = AuthSession.instance.role;
    return AuthSession.instance.isLoggedIn &&
        (role == AuthRole.client || role == AuthRole.master);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'nativeCallAction' && call.arguments is Map) {
        await _handleAction(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
    FirebaseMessaging.onMessage.listen(
      (message) => unawaited(handlePushData(message.data)),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(handlePushData(message.data)),
    );
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event != null) unawaited(_handleCallEvent(event));
    });
    _session.sessionEvents.addListener(_onSessionChanged);
    await _consumePendingActions();
    await syncForCurrentSession();
  }

  void bindCallUi(VoidCallback callback) {
    _openCallUi = callback;
    if (_uiPending) {
      _uiPending = false;
      callback();
    }
  }

  void showIncomingFromSocket(IncomingCallSignal signal) {
    unawaited(
      showIncoming(
        callId: signal.callId,
        callUuid: signal.callUuid,
        conversationId: signal.conversationId,
        callerKind: signal.from,
        callerName: signal.displayName,
      ),
    );
  }

  Future<void> syncForCurrentSession() async {
    if (!hasCallableSession) return;
    if (!_permissionsRequested) {
      _permissionsRequested = true;
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (Platform.isAndroid) {
        await FlutterCallkitIncoming.requestNotificationPermission({
          'title': 'Qo‘ng‘iroqlar uchun bildirishnoma ruxsati',
          'rationaleMessagePermission':
              'Fixleo yopiq bo‘lsa ham qo‘ng‘iroqlarni ko‘rsatish uchun ruxsat kerak.',
          'postNotificationMessageRequired': 'Ruxsatni sozlamalardan yoqing.',
        });
        if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
          await FlutterCallkitIncoming.requestFullIntentPermission();
        }
      }
    }

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await _registerToken(fcmToken, type: 'fcm');
    }
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen((token) => unawaited(_registerToken(token, type: 'fcm')));
    if (Platform.isIOS) {
      final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (voipToken != null && voipToken.isNotEmpty) {
        await _registerToken(voipToken, type: 'apns_voip');
      }
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!hasCallableSession || Firebase.apps.isEmpty) return;
    final role = _session.role!.name;
    final tokens = <String?>[
      await FirebaseMessaging.instance.getToken(),
      if (Platform.isIOS) await FlutterCallkitIncoming.getDevicePushTokenVoIP(),
    ];
    for (final token in tokens.whereType<String>().where(
      (value) => value.isNotEmpty,
    )) {
      try {
        await ApiClient.instance.delete(
          '/${role}s/me/device-tokens/${Uri.encodeComponent(token)}',
        );
      } on Object catch (error) {
        debugPrint('Push token removal deferred: $error');
      }
    }
  }

  static Future<void> handlePushData(Map<String, dynamic> data) async {
    switch (data['type']) {
      case 'incoming_call':
        if (!Platform.isAndroid || !hasCallableSession) return;
        final callId = _toInt(data['callId']);
        final conversationId = _toInt(data['conversationId']);
        final callUuid = data['callUuid']?.toString();
        if (callId == null || conversationId == null || callUuid == null) {
          return;
        }
        await instance.showIncoming(
          callId: callId,
          callUuid: callUuid,
          conversationId: conversationId,
          callerKind: data['callerKind']?.toString() ?? 'client',
          callerName: data['callerName']?.toString() ?? 'Fixleo',
        );
      case 'call_ended':
        final callUuid = data['callUuid']?.toString();
        if (callUuid != null) {
          await stopAndroidVibrationFallback();
          await FlutterCallkitIncoming.endCall(callUuid);
          CallService.instance.endIncomingFromRemote(callUuid);
        }
    }
  }

  Future<void> showIncoming({
    required int callId,
    required String callUuid,
    required int conversationId,
    required String callerKind,
    required String callerName,
  }) async {
    if (!hasCallableSession) return;
    final active = await FlutterCallkitIncoming.activeCalls();
    if (active.any((call) => call.id.toLowerCase() == callUuid.toLowerCase())) {
      return;
    }
    await FlutterCallkitIncoming.showCallkitIncoming(
      callParams(
        callId: callId,
        callUuid: callUuid,
        conversationId: conversationId,
        callerKind: callerKind,
        callerName: callerName,
      ),
    );
    await _startAndroidVibrationFallback();
  }

  /// MIUI/HyperOS ignores third-party vibrations tagged as a ringtone even
  /// when the user enabled "vibrate while ringing". The CallKit plugin uses
  /// that tag, so Xiaomi/Redmi/POCO devices need an alarm-usage waveform.
  /// This finite pattern stops by itself after roughly the call timeout and is
  /// also cancelled immediately on accept, decline, end, or timeout.
  static Future<void> _startAndroidVibrationFallback() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final vendor = '${info.manufacturer} ${info.brand}'.toLowerCase();
      const affectedVendors = <String>['xiaomi', 'redmi', 'poco'];
      if (!affectedVendors.any(vendor.contains)) return;
      if (!await Vibration.hasVibrator()) return;

      final pattern = <int>[0];
      for (var index = 0; index < 30; index++) {
        pattern.add(1000);
        if (index < 29) pattern.add(1000);
      }
      await Vibration.vibrate(pattern: pattern);
    } on Object catch (error) {
      debugPrint('Android call vibration fallback failed: $error');
    }
  }

  static Future<void> stopAndroidVibrationFallback() async {
    if (!Platform.isAndroid) return;
    try {
      await Vibration.cancel();
    } on Object catch (error) {
      debugPrint('Android call vibration cancellation failed: $error');
    }
  }

  static CallKitParams callParams({
    required int callId,
    required String callUuid,
    required int conversationId,
    required String callerKind,
    required String callerName,
  }) {
    final lang = LocaleController.language.value;
    return CallKitParams(
      id: callUuid,
      nameCaller: callerName,
      appName: 'Fixleo',
      handle: callerKind == 'master'
          ? tr(lang, 'Usta', 'Мастер', 'Master')
          : tr(lang, 'Mijoz', 'Клиент', 'Client'),
      type: 0,
      duration: 60_000,
      extra: {
        'callId': callId,
        'callUuid': callUuid,
        'conversationId': conversationId,
        'callerKind': callerKind,
        'callerName': callerName,
      },
      missedCallNotification: NotificationParams(
        showNotification: true,
        subtitle: tr(
          lang,
          'Javobsiz qo‘ng‘iroq',
          'Пропущенный звонок',
          'Missed call',
        ),
        isShowCallback: false,
      ),
      android: AndroidParams(
        isCustomNotification: true,
        isCustomSmallExNotification: true,
        isShowLogo: true,
        logoUrl: 'assets/icon/app_icon.png',
        isShowCallID: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#152343',
        actionColor: '#0D87F5',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Fixleo qo‘ng‘iroqlari',
        missedCallNotificationChannelName: 'Javobsiz qo‘ng‘iroqlar',
        isShowFullLockedScreen: true,
        isImportant: true,
        isBot: false,
        // Let Android post the high-priority call notification and launch its
        // full-screen intent. The plugin starts ringtone and vibration from
        // that notification path; opening the Activity directly bypasses both.
        isFullScreen: false,
        textAccept: tr(lang, 'Qabul qilish', 'Принять', 'Accept'),
        textDecline: tr(lang, 'Rad etish', 'Отклонить', 'Decline'),
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        includesCallsInRecents: true,
        configureAudioSession: true,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 48000.0,
        audioSessionPreferredIOBufferDuration: 0.005,
      ),
    );
  }

  static Map<String, dynamic>? eventPayload(CallEvent event) {
    String? action;
    CallKitParams? params;
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        action = 'accept';
        params = callKitParams;
      case CallEventActionCallDecline(:final callKitParams):
        action = 'decline';
        params = callKitParams;
      case CallEventActionCallEnded(:final callKitParams):
        action = 'end';
        params = callKitParams;
      case CallEventActionCallTimeout(:final id):
        return {'nativeAction': 'timeout', 'id': id};
      default:
        return null;
    }
    return {...params.toJson(), 'nativeAction': action};
  }

  static Future<void> rejectFromPayload(Map<String, dynamic> payload) async {
    if (!hasCallableSession) return;
    final callId = _callIdFrom(payload);
    final role = AuthSession.instance.role;
    if (callId == null || role == null) return;
    try {
      await ApiClient.instance.post('/${role.name}s/me/calls/$callId/reject');
    } on Object catch (error) {
      debugPrint('Native call rejection failed: $error');
    }
  }

  Future<void> _handleCallEvent(CallEvent event) async {
    if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
      await syncForCurrentSession();
      return;
    }
    final payload = eventPayload(event);
    if (payload != null) await _handleAction(payload);
  }

  Future<void> _handleAction(Map<String, dynamic> payload) async {
    final action = payload['nativeAction']?.toString();
    final callUuid = _callUuidFrom(payload);
    if (action == null || callUuid == null) return;
    final dedupeKey = '$action:$callUuid';
    if (!_handledActions.add(dedupeKey)) return;
    if (_handledActions.length > 64) {
      _handledActions.remove(_handledActions.first);
    }
    await stopAndroidVibrationFallback();

    final callId = _callIdFrom(payload);
    switch (action) {
      case 'accept':
        if (callId == null || !hasCallableSession) return;
        final extra = _extra(payload);
        await CallService.instance.answerFromNative(
          callId: callId,
          callUuid: callUuid,
          callerName:
              extra['callerName']?.toString() ??
              payload['nameCaller']?.toString() ??
              'Fixleo',
          onShowUi: _presentCallUi,
        );
      case 'decline':
        await rejectFromPayload(payload);
        CallService.instance.endIncomingFromRemote(callUuid);
      case 'end':
        if (CallService.instance.currentCallUuid == callUuid) {
          CallService.instance.hangup();
        }
      case 'timeout':
        CallService.instance.endIncomingFromRemote(callUuid);
    }
  }

  Future<void> _consumePendingActions() async {
    if (Platform.isIOS) {
      final pending = await _nativeChannel.invokeMapMethod<String, dynamic>(
        'consumePendingAction',
      );
      if (pending != null) await _handleAction(pending);
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingBackgroundActionKey);
    if (raw != null) {
      await prefs.remove(_pendingBackgroundActionKey);
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        await _handleAction(Map<String, dynamic>.from(parsed));
      }
    }
  }

  Future<void> _registerToken(String token, {required String type}) async {
    if (!hasCallableSession || token.isEmpty) return;
    try {
      await ApiClient.instance.post(
        '/${_session.role!.name}s/me/device-tokens',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'type': type,
        },
      );
    } on Object catch (error) {
      debugPrint('Push token registration deferred: $error');
    }
  }

  void _presentCallUi() {
    final callback = _openCallUi;
    if (callback == null) {
      _uiPending = true;
    } else {
      callback();
    }
  }

  void _onSessionChanged() {
    unawaited(syncForCurrentSession());
  }

  static Map<String, dynamic> _extra(Map<String, dynamic> payload) {
    final value = payload['extra'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static int? _callIdFrom(Map<String, dynamic> payload) {
    return _toInt(_extra(payload)['callId'] ?? payload['callId']);
  }

  static String? _callUuidFrom(Map<String, dynamic> payload) {
    return (_extra(payload)['callUuid'] ?? payload['id'] ?? payload['callUuid'])
        ?.toString();
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
