import 'package:fixleo/app/widgets/app_feedback.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/realtime/call_service.dart';
import 'package:fixleo/core/permissions/permission_prompt.dart';
import 'push_delivery_policy.dart';
import 'push_sync_retry.dart';

const _pendingBackgroundActionKey = 'pending_native_call_action';
const _nativeCallsChannelName = 'com.fixleo.app/native_calls';

class AppPushNotification {
  const AppPushNotification({
    required this.title,
    required this.body,
    required this.data,
  });

  final String title;
  final String body;
  final Map<String, dynamic> data;

  factory AppPushNotification.fromRemoteMessage(RemoteMessage message) {
    return AppPushNotification(
      title:
          message.notification?.title ??
          message.data['title']?.toString() ??
          'Fixleo',
      body:
          message.notification?.body ?? message.data['body']?.toString() ?? '',
      data: {
        ...message.data,
        if (message.messageId != null) '_remoteMessageId': message.messageId,
      },
    );
  }
}

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
  final _deliveryPolicy = PushDeliveryPolicy();
  late final _tokenSync = PushSyncRetry(_syncTokens);
  bool _foreground = true;
  bool _unregistering = false;
  VoidCallback? _openCallUi;
  void Function(AppPushNotification notification)? _showNotificationUi;
  void Function(AppPushNotification notification)? _openNotificationUi;
  AppPushNotification? _pendingOpenedNotification;
  int? _activeConversationId;
  bool _initialized = false;
  bool _permissionsRequested = false;
  bool _permissionPromptHandled = false;
  bool _permissionPromptActive = false;
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
    FirebaseMessaging.onMessage.listen((message) {
      if (_isCallPush(message.data)) {
        unawaited(handlePushData(message.data));
      } else {
        _showForegroundNotification(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_isCallPush(message.data)) {
        unawaited(handlePushData(message.data));
      } else {
        _openNotification(AppPushNotification.fromRemoteMessage(message));
      }
    });
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event != null) unawaited(_handleCallEvent(event));
    });
    _session.sessionEvents.addListener(_onSessionChanged);
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen(
          (_) => unawaited(syncForCurrentSession()),
          onError: (Object error) => unawaited(syncForCurrentSession()),
        );
    // The Flutter banner is the sole foreground presentation on iOS.
    // Background alerts remain owned by APNs/FCM, avoiding duplicate alerts.
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
    } on Object {
      debugPrint('Push foreground presentation configuration unavailable');
    }
    try {
      await _consumePendingActions();
    } on Object {
      debugPrint('Pending native action unavailable at startup');
    }
    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null && !_isCallPush(initialMessage.data)) {
        _openNotification(
          AppPushNotification.fromRemoteMessage(initialMessage),
        );
      }
    } on Object {
      debugPrint('Initial push unavailable at startup');
    }
    unawaited(syncForCurrentSession());
  }

  void bindCallUi(VoidCallback callback) {
    _openCallUi = callback;
    if (_uiPending) {
      _uiPending = false;
      callback();
    }
  }

  void bindNotificationUi({
    required void Function(AppPushNotification notification) show,
    required void Function(AppPushNotification notification) open,
  }) {
    _showNotificationUi = show;
    _openNotificationUi = open;
    final pending = _pendingOpenedNotification;
    if (pending != null) {
      _pendingOpenedNotification = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => open(pending));
    }
  }

  void unbindNotificationUi() {
    _showNotificationUi = null;
    _openNotificationUi = null;
    _openCallUi = null;
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value) unawaited(syncForCurrentSession());
  }

  void setActiveConversation(int conversationId) {
    _activeConversationId = conversationId;
  }

  void clearActiveConversation(int conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (!hasCallableSession || !_foreground) return;
    final notification = AppPushNotification.fromRemoteMessage(message);
    if (!_deliveryPolicy.belongsTo(
      notification.data,
      _session.role!.name,
      _session.subjectId,
    )) {
      return;
    }
    final conversationId = _toInt(notification.data['conversationId']);
    if (notification.data['type'] == 'chat_message' &&
        conversationId != null &&
        conversationId == _activeConversationId) {
      return;
    }
    if (_showNotificationUi != null &&
        _deliveryPolicy.acceptShown(notification.data)) {
      _showNotificationUi?.call(notification);
    }
  }

  void _openNotification(AppPushNotification notification) {
    if (!hasCallableSession ||
        !_deliveryPolicy.belongsTo(
          notification.data,
          _session.role!.name,
          _session.subjectId,
        ) ||
        !_deliveryPolicy.acceptOpened(notification.data)) {
      return;
    }
    if (notification.data['type'] == 'chat_message' &&
        _activeConversationId == _toInt(notification.data['conversationId'])) {
      return;
    }
    final callback = _openNotificationUi;
    if (callback == null) {
      _pendingOpenedNotification = notification;
    } else {
      callback(notification);
    }
  }

  static bool _isCallPush(Map<String, dynamic> data) {
    return data['type'] == 'incoming_call' || data['type'] == 'call_ended';
  }

  void showIncomingFromSocket(IncomingCallSignal signal) {
    unawaited(
      showIncoming(
        callId: signal.callId,
        callUuid: signal.callUuid,
        conversationId: signal.conversationId,
        callerKind: signal.from,
        callerName: signal.displayName,
        callerAvatarUrl: signal.avatarUrl,
      ),
    );
  }

  /// Shows a Fixleo explanation first and only then opens Android/iOS system
  /// permission surfaces. This must be called from an authenticated screen,
  /// never before [runApp], so the user understands what is being requested.
  Future<void> requestPermissions(BuildContext context) async {
    if (!hasCallableSession || _permissionPromptActive) return;
    _permissionPromptActive = true;
    try {
      await _requestPermissions(context);
    } on Object {
      debugPrint('Notification permission request unavailable');
    } finally {
      _permissionPromptActive = false;
    }
  }

  Future<void> _requestPermissions(BuildContext context) async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final notificationsReady =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    var fullScreenReady = true;
    if (Platform.isAndroid) {
      try {
        fullScreenReady = await FlutterCallkitIncoming.canUseFullScreenIntent();
      } on Object {
        fullScreenReady = false;
      }
    }
    if (notificationsReady && fullScreenReady) {
      await syncForCurrentSession();
      return;
    }
    if (_permissionPromptHandled || !context.mounted) return;

    final shouldContinue = await showPermissionRationale(
      context,
      icon: Icons.notifications_active_outlined,
      titleUz: 'Qo‘ng‘iroq va bildirishnomalar',
      titleRu: 'Звонки и уведомления',
      titleEn: 'Calls and notifications',
      messageUz:
          'Fixleo yopiq yoki ekran bloklangan bo‘lsa ham qo‘ng‘iroq va muhim xabarlarni ko‘rsatishi uchun bildirishnoma ruxsati kerak.',
      messageRu:
          'Разрешите уведомления, чтобы Fixleo показывал входящие звонки и важные сообщения, даже когда приложение закрыто или экран заблокирован.',
      messageEn:
          'Allow notifications so Fixleo can show incoming calls and important messages even when the app is closed or the screen is locked.',
    );
    _permissionPromptHandled = true;
    if (!shouldContinue) return;
    if (!_permissionsRequested) {
      _permissionsRequested = true;
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    final updatedSettings = await FirebaseMessaging.instance
        .getNotificationSettings();
    final notificationsGranted =
        updatedSettings.authorizationStatus == AuthorizationStatus.authorized ||
        updatedSettings.authorizationStatus == AuthorizationStatus.provisional;
    if (!notificationsGranted) {
      if (context.mounted) _showSettingsHint(context);
      return;
    }

    await syncForCurrentSession();
    if (Platform.isAndroid &&
        !await FlutterCallkitIncoming.canUseFullScreenIntent() &&
        context.mounted) {
      final allowFullScreen = await showPermissionRationale(
        context,
        icon: Icons.phone_in_talk_rounded,
        titleUz: 'Qulflangan ekrandagi qo‘ng‘iroq',
        titleRu: 'Звонок на заблокированном экране',
        titleEn: 'Calls on the lock screen',
        messageUz:
            'Kiruvchi qo‘ng‘iroqni ekran qulflanganda ham to‘liq ko‘rsatish uchun Fixleo’ga maxsus ruxsat bering.',
        messageRu:
            'Разрешите Fixleo показывать входящий вызов на весь экран, когда телефон заблокирован.',
        messageEn:
            'Allow Fixleo to show incoming calls full-screen while the phone is locked.',
      );
      if (allowFullScreen) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    }
  }

  void _showSettingsHint(BuildContext context) {
    final lang = LocaleController.language.value;
    AppFeedback.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            lang,
            'Bildirishnomalar bloklangan. Qo‘ng‘iroq va xabarlar uchun sozlamalardan yoqing.',
            'Уведомления заблокированы. Включите их в настройках для звонков и сообщений.',
            'Notifications are blocked. Enable them in Settings for calls and messages.',
          ),
        ),
        action: SnackBarAction(
          label: tr(lang, 'Sozlamalar', 'Настройки', 'Settings'),
          onPressed: () => unawaited(Geolocator.openAppSettings()),
        ),
      ),
    );
  }

  Future<void> syncForCurrentSession() {
    if (!hasCallableSession || _unregistering || Firebase.apps.isEmpty) {
      return Future.value();
    }
    return _tokenSync.sync();
  }

  Future<bool> _syncTokens() async {
    if (!hasCallableSession || _unregistering) return true;
    final epoch = _session.sessionEvents.value;
    var ready = true;
    // APNs can arrive later than Firebase initialization on a real iPhone.
    // Register VoIP independently, even if the regular APNs token is not ready.
    if (Platform.isIOS) {
      try {
        final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (voipToken != null && voipToken.isNotEmpty) {
          ready = await _registerToken(
            voipToken,
            type: 'apns_voip',
            epoch: epoch,
          );
        } else {
          ready = false;
        }
      } on Object {
        ready = false;
      }
      if (await FirebaseMessaging.instance.getAPNSToken() == null) return false;
    }
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null || fcmToken.isEmpty) return false;
    final registered = await _registerToken(
      fcmToken,
      type: 'fcm',
      epoch: epoch,
    );
    return ready && registered;
  }

  Future<void> unregisterCurrentDevice() async {
    _unregistering = true;
    _tokenSync.reset();
    if (!hasCallableSession || Firebase.apps.isEmpty) return;
    final role = _session.role!.name;
    final tokens = <String?>[];
    try {
      if (!Platform.isIOS ||
          await FirebaseMessaging.instance.getAPNSToken() != null) {
        tokens.add(await FirebaseMessaging.instance.getToken());
      }
    } on Object {
      debugPrint('FCM token unavailable during logout');
    }
    if (Platform.isIOS) {
      try {
        tokens.add(await FlutterCallkitIncoming.getDevicePushTokenVoIP());
      } on Object {
        debugPrint('VoIP token unavailable during logout');
      }
    }
    for (final token in tokens.whereType<String>().where(
      (value) => value.isNotEmpty,
    )) {
      try {
        await ApiClient.instance.delete(
          '/${role}s/me/device-tokens/${Uri.encodeComponent(token)}',
        );
      } on Object {
        debugPrint('Push token removal deferred');
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
          callerAvatarUrl: data['callerAvatarUrl']?.toString(),
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
    String? callerAvatarUrl,
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
        callerAvatarUrl: callerAvatarUrl,
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
    String? callerAvatarUrl,
  }) {
    final lang = LocaleController.language.value;
    final avatarUrl = ApiConfig.resolveMediaUrl(callerAvatarUrl);
    return CallKitParams(
      id: callUuid,
      nameCaller: callerName,
      appName: 'Fixleo',
      avatar: avatarUrl ?? 'assets/icon/app_icon.png',
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
        'callerAvatarUrl': ?avatarUrl,
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
        isShowLogo: false,
        isShowCallID: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#071327',
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
          callerAvatarUrl: extra['callerAvatarUrl']?.toString(),
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

  Future<bool> _registerToken(
    String token, {
    required String type,
    required int epoch,
  }) async {
    if (!hasCallableSession ||
        _unregistering ||
        token.isEmpty ||
        epoch != _session.sessionEvents.value) {
      return true;
    }
    try {
      await ApiClient.instance.post(
        '/${_session.role!.name}s/me/device-tokens',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'type': type,
        },
      );
      return true;
    } on Object {
      // Never log request bodies: they contain device push tokens.
      debugPrint('Push token registration deferred ($type)');
      return false;
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
    _unregistering = false;
    _tokenSync.reset();
    _deliveryPolicy.clear();
    _pendingOpenedNotification = null;
    _activeConversationId = null;
    _permissionPromptHandled = false;
    _permissionsRequested = false;
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
