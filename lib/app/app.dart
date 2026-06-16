import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_theme.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';

class FixleoApp extends StatelessWidget {
  const FixleoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fixleo',
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
