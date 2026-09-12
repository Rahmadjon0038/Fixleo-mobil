import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/auth/presentation/phone_screen.dart';

/// Onboarding screen shown after the splash. Lets the user start as a
/// client ("create first request") or switch to the master flow.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _navy = Color(0xFF16233F);
  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
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
              tr(
                lang,
                'Ustalar yaqin va tez',
                'Мастера рядом и быстро',
                'Masters nearby and fast',
              ),
              style: TextStyle(
                fontSize: 15,
                color: _navy.withValues(alpha: 0.55),
              ),
            ),
            const Spacer(flex: 4),
            _PrimaryButton(
              label: tr(
                lang,
                'Birinchi buyurtma yaratish',
                'Создать первую заявку',
                'Create first request',
              ),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PhoneScreen()));
              },
            ),
            const SizedBox(height: 12),
            LiquidActionButton.text(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PhoneScreen(isMaster: true),
                  ),
                );
              },
              child: Text(
                tr(
                  lang,
                  'Men ustaman — buyurtma olmoqchiman',
                  'Я мастер — хочу брать заказы',
                  'I am a master — I want to take orders',
                ),
                style: const TextStyle(
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
    return GlassContainer(
      width: 120,
      height: 120,
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
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
    return GlassButton(
      label: label,
      onPressed: onPressed,
      icon: Icons.add,
      height: 56,
    );
  }
}
