import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';
import 'package:fixleo/features/master/presentation/master_startup_router.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';

/// First screen shown on launch. Displays the FixLeo logo, then routes:
///   * a persisted client session → client home;
///   * a persisted master session → master home (or onboarding if KYC isn't
///     approved yet);
///   * otherwise → the onboarding intro (first-run flow).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onReady});
  final VoidCallback? onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(_splashDuration);
    if (!mounted) return;

    final session = AuthSession.instance;
    final next = await _destination(session);
    if (!mounted) return;
    final onReady = widget.onReady;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => next));
    WidgetsBinding.instance.addPostFrameCallback((_) => onReady?.call());
  }

  Future<Widget> _destination(AuthSession session) async {
    if (!session.isLoggedIn) return const IntroScreen();

    switch (session.role) {
      case AuthRole.client:
        return const HomeScreen();
      case AuthRole.master:
        try {
          final service = MasterService();
          final master = await service.me();
          return resolveMasterStartupScreen(service, master);
        } catch (_) {
          if (!session.isLoggedIn) return const IntroScreen();
          return const MasterHomeScreen();
        }
      case AuthRole.admin:
      case null:
        return const IntroScreen();
    }
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
