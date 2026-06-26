import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/welcome/presentation/welcome_screen.dart';

class _Language {
  const _Language(this.lang, this.name, this.script);
  final AppLanguage lang;
  final String name;
  final String script;
}

/// Language selection — the first onboarding step for both client and master.
/// Picking a language sets it app-wide immediately, so the rest of the flow is
/// already translated.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  static const _languages = [
    _Language(AppLanguage.uz, 'O‘zbekcha', 'Lotin'),
    _Language(AppLanguage.ru, 'Русский', 'Кириллица'),
    _Language(AppLanguage.en, 'English', 'Latin'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Til tanlash', 'Выбор языка', 'Select language'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _languages.length; i++) ...[
                    if (i != 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black12,
                      ),
                    _LanguageTile(
                      language: _languages[i],
                      selected: lang == _languages[i].lang,
                      onTap: () =>
                          setState(() => LocaleController.set(_languages[i].lang)),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final _Language language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    language.script,
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
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
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.blue : Colors.black26,
          width: 2,
        ),
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
