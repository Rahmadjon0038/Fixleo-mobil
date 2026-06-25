import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/language/presentation/language_screen.dart';

/// Onboarding screen shown after the splash. Lets the user start as a
/// client ("create first request") or switch to the master flow.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _navy = Color(0xFF16233F);
  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            _Logo(),
            const SizedBox(height: 20),
            const Text(
              'FixLeo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _navy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ustalar yaqin va tez',
              style: TextStyle(
                fontSize: 15,
                color: _navy.withValues(alpha: 0.55),
              ),
            ),
            const Spacer(flex: 4),
            _PrimaryButton(
              label: 'Birinchi buyurtma yaratish',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LanguageScreen(isMaster: true),
                  ),
                );
              },
              child: const Text(
                'Men ustaman — buyurtma olmoqchiman',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SvgPicture.asset('assets/logo.svg'),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: WelcomeScreen._blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        icon: const Icon(Icons.add, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
