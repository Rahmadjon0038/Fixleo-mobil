import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';

/// Master's profile tab — mirrors the client profile layout: account header,
/// a working language switcher (O‘zbekcha / Русский), grouped settings rows and
/// a logout pill. Shown under the "Profil" tab.
class MasterProfileTabScreen extends StatelessWidget {
  const MasterProfileTabScreen({super.key});

  static const _gray = Color(0xFF8D96A4);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _red50 = Color(0xFFFEF2F2);
  static const _red700 = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _userCard(),
        const SizedBox(height: 8),
        _languageCard(lang),
        const SizedBox(height: 8),
        _group([
          _MenuItem(
            icon: Icons.person_outline,
            label: tr(lang, 'Mening maʼlumotlarim', 'Мои данные'),
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.history,
            label: tr(lang, 'Ishlar tarixi', 'История работ'),
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: tr(lang, 'Sozlamalar', 'Настройки'),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 8),
        _group([
          _MenuItem(
            icon: Icons.notifications_outlined,
            label: tr(lang, 'Bildirishnomalar', 'Уведомления'),
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.headset_mic_outlined,
            label: tr(lang, 'Qoʻllab-quvvatlash', 'Поддержка'),
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.shield_outlined,
            label: tr(lang, 'Maxfiylik siyosati', 'Политика конфиденциальности'),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 8),
        _logout(context, lang),
      ],
    );
  }

  /// Avatar + name + phone header card.
  Widget _userCard() {
    return Container(
      width: double.infinity,
      height: 155,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person, size: 38, color: _gray),
          ),
          const SizedBox(height: 4),
          const Text(
            'Arslan Koptleulov',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const Text(
            '+998 90 000 00 00',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: _gray,
            ),
          ),
        ],
      ),
    );
  }

  /// Language switcher card (O‘zbekcha / Русский).
  Widget _languageCard(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Til', 'Язык'),
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          _LangOption(
            title: 'O‘zbekcha',
            selected: lang == AppLanguage.uz,
            onTap: () => LocaleController.set(AppLanguage.uz),
          ),
          const SizedBox(height: 8),
          _LangOption(
            title: 'Русский',
            selected: lang == AppLanguage.ru,
            onTap: () => LocaleController.set(AppLanguage.ru),
          ),
        ],
      ),
    );
  }

  /// A white rounded card grouping menu rows separated by dividers.
  Widget _group(List<_MenuItem> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 4, 20, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            items[i],
          ],
        ],
      ),
    );
  }

  /// Red logout pill.
  Widget _logout(BuildContext context, AppLanguage lang) {
    return GestureDetector(
      onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _red50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, size: 22, color: _red700),
            ),
            const SizedBox(width: 10),
            Text(
              tr(lang, 'Akkauntdan chiqish', 'Выйти из аккаунта'),
              style: const TextStyle(
                fontSize: 16,
                height: 22 / 16,
                letterSpacing: -0.18,
                fontWeight: FontWeight.w600,
                color: _red700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable language row with a radio dot.
class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.blue : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.blue : const Color(0xFFCBD5E1),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable settings row: icon bubble, label and a chevron.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: MasterProfileTabScreen._slate50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: MasterProfileTabScreen._gray,
            ),
          ],
        ),
      ),
    );
  }
}
