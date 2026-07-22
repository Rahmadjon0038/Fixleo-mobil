import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    // FixLeo brand blue (FINAL design) — keeps Material widgets (spinners,
    // text buttons, cursors) on-brand instead of the old teal.
    const seedColor = Color(0xFF0079EB);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }
}
