import 'package:flutter/material.dart';

/// Shared brand colors used across the app's screens.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF1C274C);
  static const blue = Color(0xFF0079EB);
  static const background = Color(0xFFF4F5F7);

  /// Muted text color (subtitles, hints).
  static const muted = Color(0xFF94A3B8);

  /// Error/danger color (invalid input, inline error messages).
  static const danger = Color(0xFFEF4444);

  /// Dark hero-card background (FINAL design `neutral/900`).
  static const heroDark = Color(0xFF121722);

  /// Bright edge highlight on every "Liquid Glass" panel — see
  /// `lib/app/widgets/glass/glass_container.dart`.
  static const glassBorder = Colors.white;

  /// Base surface tint for light glass panels (cards, sheets, fields).
  static const glassTint = Colors.white;

  /// Shadow cast by floating glass panels (nav bar, cards, buttons).
  static const glassShadow = Color(0xFF0F172A);
}
