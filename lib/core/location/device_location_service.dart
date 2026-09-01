import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

enum DeviceLocationPermissionState { granted, denied, deniedForever }

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.failure);

  final DeviceLocationFailure failure;
}

/// Requests foreground location permission and returns the device's current
/// coordinates. Background access is intentionally not requested.
class DeviceLocationService {
  Future<DeviceLocationPermissionState> permissionState() async {
    final permission = await Geolocator.checkPermission();
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => DeviceLocationPermissionState.granted,
      LocationPermission.deniedForever =>
        DeviceLocationPermissionState.deniedForever,
      LocationPermission.denied || LocationPermission.unableToDetermine =>
        DeviceLocationPermissionState.denied,
    };
  }

  Future<LatLng> currentLocation() async {
    try {
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on DeviceLocationException {
      rethrow;
    } on TimeoutException {
      throw const DeviceLocationException(DeviceLocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
      );
    } catch (_) {
      throw const DeviceLocationException(DeviceLocationFailure.unavailable);
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
