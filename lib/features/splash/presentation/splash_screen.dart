import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/welcome/presentation/welcome_screen.dart';

/// First screen shown on launch. Displays the FixLeo logo, then
/// navigates to [WelcomeScreen] after a short delay.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _goToWelcome();
  }

  Future<void> _goToWelcome() async {
    await Future.delayed(_splashDuration);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      body: Center(
        child: SvgPicture.asset('assets/logo.svg', width: 110, height: 110),
      ),
    );
  }
}
