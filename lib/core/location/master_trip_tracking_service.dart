import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixleo/core/location/device_location_service.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';

enum MasterTripTrackingPhase { idle, starting, active, unavailable }

@immutable
class MasterTripTrackingState {
  const MasterTripTrackingState({
    this.phase = MasterTripTrackingPhase.idle,
    this.orderId,
    this.lastPosition,
    this.lastSentAt,
    this.hasNetworkError = false,
  });

  final MasterTripTrackingPhase phase;
  final int? orderId;
  final Position? lastPosition;
  final DateTime? lastSentAt;
  final bool hasNetworkError;

  bool get isActive => phase == MasterTripTrackingPhase.active;
}

/// Keeps an accepted master's trip location alive while an external navigator
/// is in front. Only the last point is sent; Fixleo never records a route
/// history on the device.
class MasterTripTrackingService {
  MasterTripTrackingService._();

  static final MasterTripTrackingService instance =
      MasterTripTrackingService._();

  static const _orderKey = 'active_master_trip_order_id';
  static const _ownerKey = 'active_master_trip_owner_id';
  static const _minSendInterval = Duration(seconds: 4);
  static const _minSendDistanceMeters = 15.0;

  final ValueNotifier<MasterTripTrackingState> state = ValueNotifier(
    const MasterTripTrackingState(),
  );
  final MasterMarketplaceService _market = MasterMarketplaceService();

  StreamSubscription<Position>? _subscription;
  Position? _lastSentPosition;
  DateTime? _lastAttemptAt;
  Position? _pendingPosition;
  bool _sending = false;

  LocationSettings get _locationSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _minSendDistanceMeters.round(),
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FixLeo yo\u02bbl davom etmoqda',
          notificationText: 'Lokatsiyangiz mijozga ko\u02bbrsatilmoqda',
          notificationChannelName: 'Buyurtma lokatsiyasi',
          notificationIcon: AndroidResource(
            name: 'ic_stat_fixleo',
            defType: 'drawable',
          ),
          enableWakeLock: true,
          setOngoing: true,
          color: Color(0xFF1294E8),
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: _minSendDistanceMeters.round(),
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
  }

  /// User-triggered preflight. This must run while Fixleo is visible, before
  /// the external navigation app is opened (required by modern Android).
  Future<Position> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
    } on TimeoutException {
      throw const DeviceLocationException(DeviceLocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
      );
    } on PermissionDeniedException {
      throw const DeviceLocationException(
        DeviceLocationFailure.permissionDenied,
      );
    }
  }

  Future<void> start({required int orderId, Position? initialPosition}) async {
    if (state.value.isActive && state.value.orderId == orderId) return;
    await _cancelSubscription();
    state.value = MasterTripTrackingState(
      phase: MasterTripTrackingPhase.starting,
      orderId: orderId,
    );

    final position = initialPosition ?? await ensureReady();
    final ownerId = AuthSession.instance.subjectId;
    if (AuthSession.instance.role != AuthRole.master || ownerId == null) {
      state.value = const MasterTripTrackingState();
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_orderKey, orderId);
    await preferences.setInt(_ownerKey, ownerId);

    state.value = MasterTripTrackingState(
      phase: MasterTripTrackingPhase.active,
      orderId: orderId,
      lastPosition: position,
    );
    await _enqueue(position, force: true);
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings,
        ).listen(
          (next) => unawaited(_enqueue(next)),
          onError: (_) {
            final current = state.value;
            state.value = MasterTripTrackingState(
              phase: MasterTripTrackingPhase.unavailable,
              orderId: current.orderId,
              lastPosition: current.lastPosition,
              lastSentAt: current.lastSentAt,
              hasNetworkError: current.hasNetworkError,
            );
          },
        );
  }

  /// Resumes a persisted trip after a normal process restart. It never opens a
  /// permission prompt by itself; denied permission is handled when the master
  /// returns to the order screen.
  Future<void> syncForCurrentSession() async {
    final session = AuthSession.instance;
    if (session.role != AuthRole.master || session.subjectId == null) {
      await stop();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final orderId = preferences.getInt(_orderKey);
    final ownerId = preferences.getInt(_ownerKey);
    if (orderId == null || ownerId != session.subjectId) {
      await stop();
      return;
    }
    try {
      final order = await _market.orderDetail(orderId);
      if (order.status != 'on_the_way') {
        await stop();
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          !await Geolocator.isLocationServiceEnabled()) {
        state.value = MasterTripTrackingState(
          phase: MasterTripTrackingPhase.unavailable,
          orderId: orderId,
        );
        return;
      }
      await start(orderId: orderId);
    } on ApiException catch (error) {
      if (!error.isNetworkError &&
          (error.statusCode == 403 ||
              error.statusCode == 404 ||
              error.statusCode == 409)) {
        await stop();
        return;
      }
      state.value = MasterTripTrackingState(
        phase: MasterTripTrackingPhase.unavailable,
        orderId: orderId,
        hasNetworkError: true,
      );
    } on Object {
      // Keep the persisted trip across a transient API/network outage. The
      // order screen can retry it after connectivity returns.
      state.value = MasterTripTrackingState(
        phase: MasterTripTrackingPhase.unavailable,
        orderId: orderId,
        hasNetworkError: true,
      );
    }
  }

  Future<void> stop() async {
    await _cancelSubscription();
    _lastSentPosition = null;
    _lastAttemptAt = null;
    _pendingPosition = null;
    _sending = false;
    state.value = const MasterTripTrackingState();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_orderKey);
    await preferences.remove(_ownerKey);
  }

  Future<void> _cancelSubscription() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _enqueue(Position position, {bool force = false}) async {
    final orderId = state.value.orderId;
    if (orderId == null) return;
    final now = DateTime.now();
    final previous = _lastSentPosition;
    final lastAttempt = _lastAttemptAt;
    if (!force && previous != null && lastAttempt != null) {
      final distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      if (now.difference(lastAttempt) < _minSendInterval &&
          distance < _minSendDistanceMeters) {
        return;
      }
    }

    if (_sending) {
      _pendingPosition = position;
      return;
    }
    _sending = true;
    _lastAttemptAt = now;
    try {
      await _market.pingLocation(
        orderId: orderId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
        headingDegrees: position.heading.isFinite && position.heading >= 0
            ? position.heading
            : null,
        speedMps: position.speed.isFinite && position.speed >= 0
            ? position.speed
            : null,
      );
      _lastSentPosition = position;
      state.value = MasterTripTrackingState(
        phase: MasterTripTrackingPhase.active,
        orderId: orderId,
        lastPosition: position,
        lastSentAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      // A structured terminal response means the trip no longer belongs to an
      // active on-the-way order. Stop the OS location stream immediately so a
      // stale foreground notification cannot survive a cancellation.
      if (!error.isNetworkError &&
          (error.statusCode == 403 ||
              error.statusCode == 404 ||
              error.statusCode == 409)) {
        await stop();
        return;
      }
      final current = state.value;
      state.value = MasterTripTrackingState(
        phase: MasterTripTrackingPhase.active,
        orderId: orderId,
        lastPosition: position,
        lastSentAt: current.lastSentAt,
        hasNetworkError: true,
      );
    } on Object {
      final current = state.value;
      state.value = MasterTripTrackingState(
        phase: MasterTripTrackingPhase.active,
        orderId: orderId,
        lastPosition: position,
        lastSentAt: current.lastSentAt,
        hasNetworkError: true,
      );
    } finally {
      _sending = false;
      final pending = _pendingPosition;
      _pendingPosition = null;
      if (pending != null && state.value.orderId == orderId) {
        unawaited(_enqueue(pending, force: true));
      }
    }
  }
}
