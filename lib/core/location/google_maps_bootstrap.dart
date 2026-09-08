import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Configures the Android map implementation before the first map widget is
/// created. Explicitly preferring the latest renderer avoids devices silently
/// choosing the deprecated legacy renderer, which can render a white surface
/// on some recent Android/MIUI GPU combinations.
Future<void> initializeGoogleMapsRenderer() async {
  if (!Platform.isAndroid) return;
  final implementation = GoogleMapsFlutterPlatform.instance;
  if (implementation is! GoogleMapsFlutterAndroid) return;

  // Texture composition is faster on emulators, but a number of physical
  // Xiaomi/Redmi/POCO GPU stacks leave the Google Maps platform texture blank
  // while Flutter overlays still render. Hybrid composition is slightly more
  // expensive but is the reliable path on real devices.
  var isPhysicalDevice = true;
  try {
    isPhysicalDevice = (await DeviceInfoPlugin().androidInfo).isPhysicalDevice;
  } on Object {
    // Reliability is the safer fallback when device inspection is unavailable.
  }
  implementation.useAndroidViewSurface = isPhysicalDevice;
  try {
    await implementation.initializeWithRenderer(AndroidMapRenderer.latest);
  } on PlatformException catch (error) {
    // Some old devices can only provide the legacy renderer. Google Maps will
    // fall back automatically; the application must remain usable there.
    debugPrint('Google Maps renderer fallback: ${error.message}');
  }
}

/// Moves the SDK's first-use initialization work to the splash frame instead
/// of blocking the first interactive map screen.
Future<void> warmUpGoogleMaps() async {
  if (!Platform.isAndroid) return;
  final implementation = GoogleMapsFlutterPlatform.instance;
  if (implementation is! GoogleMapsFlutterAndroid) return;
  try {
    await implementation.warmup();
  } on PlatformException catch (error) {
    debugPrint('Google Maps warmup skipped: ${error.message}');
  }
}
