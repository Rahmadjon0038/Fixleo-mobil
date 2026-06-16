import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const seedColor = Color(0xFF0F766E);

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
