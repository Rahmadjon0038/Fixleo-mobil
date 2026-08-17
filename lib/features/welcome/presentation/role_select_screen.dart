import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/auth/presentation/phone_screen.dart';
import 'package:fixleo/features/language/presentation/language_screen.dart';

/// "Кто вы?" onboarding step — choose between the client and master flows.
/// The choice only picks which auth flow starts; the info pill reminds the
/// user the role can be changed later in the profile.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _isMaster = false;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Kim siz?', 'Кто вы?', 'Who are you?'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _RoleOption(
                    icon: Icons.person_outline,
                    title: tr(
                      lang,
                      'Men mijozman',
                      'Я заказчик',
                      'I am a client',
                    ),
                    subtitle: tr(
                      lang,
                      'Usta chaqirmoqchiman',
                      'Хочу заказать услуги',
                      'I want to order services',
                    ),
                    selected: !_isMaster,
                    onTap: () => setState(() => _isMaster = false),
                  ),
                  const SizedBox(height: 8),
                  _RoleOption(
                    icon: Icons.construction,
                    title: tr(lang, 'Men ustaman', 'Я мастер', 'I am a master'),
                    subtitle: tr(
                      lang,
                      'Buyurtmalar olmoqchiman',
                      'Хочу получать заказы',
                      'I want to take orders',
                    ),
                    selected: _isMaster,
                    onTap: () => setState(() => _isMaster = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tr(
                        lang,
                        'Rolni keyinroq profilda oʻzgartirish mumkin',
                        'Роль можно сменить позже в профиле',
                        'You can change the role later in your profile',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        letterSpacing: -0.16,
                        color: AppColors.blue,
                      ),
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
                  MaterialPageRoute(
                    builder: (_) => LocaleController.hasSavedLanguage
                        ? PhoneScreen(isMaster: _isMaster)
                        : LanguageScreen(isMaster: _isMaster),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable role row: icon bubble, title/subtitle and a radio dot.
/// The selected row gets a light slate background.
class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate200 = Color(0xFFE2E8F0);

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _slate100 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? Colors.white : _slate100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 25, color: AppColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: _RoleOption._slate200, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
