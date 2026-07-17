import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/welcome/presentation/role_select_screen.dart';

/// First onboarding screen after the splash — app preview image and the
/// "Masters nearby and fast" pitch. "Далее" continues to the role picker.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/onboarding_intro.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    tr(lang, 'Ustalar yaqin\nva tez', 'Мастера рядом\nи быстро',
                        'Masters nearby\nand fast'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      letterSpacing: -0.15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      lang,
                      'Uyingiz uchun tekshirilgan mutaxassislar — '
                          'santexnika, elektrika, klining va yana 9 ta toifa.',
                      'Проверенные специалисты для дома в вашем районе '
                          'Ташкента — сантехника, электрика, клининг и ещё '
                          '9 категорий.',
                      'Verified home specialists in your area — plumbing, '
                          'electrics, cleaning and 9 more categories.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      color: Color(0xFF8D96A4),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(lang, 'Keyingi', 'Далее', 'Next'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
