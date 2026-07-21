import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/review_request_screen.dart';

/// Step 4 of the "new request" flow — choose how urgently the master is
/// needed and (optionally) a time slot for today.
class TimeUrgencyScreen extends StatefulWidget {
  const TimeUrgencyScreen({super.key});

  @override
  State<TimeUrgencyScreen> createState() => _TimeUrgencyScreenState();
}

class _TimeUrgencyScreenState extends State<TimeUrgencyScreen> {
  static const _slots = [
    '10:00–12:00',
    '12:00–15:00',
    '15:00–18:00',
    '18:00–21:00',
  ];

  int _option = 0;
  int _slot = 1;

  List<({String title, String subtitle})> _options(AppLanguage lang) => [
        (
          title: tr(
            lang,
            'Shoshilinch — hozir',
            'Срочно — сейчас',
            'Urgent — now',
          ),
          subtitle: tr(
            lang,
            'Usta bir soat ichida yetib keladi',
            'Мастер приедет в течение часа',
            'The master arrives within an hour',
          ),
        ),
        (
          title: tr(lang, 'Bugun', 'Сегодня', 'Today'),
          subtitle: tr(
            lang,
            'Qulay vaqtni tanlang',
            'Выберите удобное время',
            'Choose a convenient time',
          ),
        ),
        (
          title: tr(
            lang,
            'Ertaga yoki keyinroq',
            'Завтра или позже',
            'Tomorrow or later',
          ),
          subtitle: tr(
            lang,
            'Sanani rejalashtirish',
            'Запланировать дату',
            'Schedule a date',
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Usta qachon kerak',
        'Когда нужен мастер',
        'When do you need the master',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _optionsCard(lang),
                    const SizedBox(height: 14),
                    _slotsCard(lang),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // "Davom etish" — Figma pill: 52px tall, fully rounded.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReviewRequestScreen(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionsCard(AppLanguage lang) {
    final options = _options(lang);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _OptionTile(
              title: options[i].title,
              subtitle: options[i].subtitle,
              selected: _option == i,
              onTap: () => setState(() => _option = i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slotsCard(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              tr(lang, 'Bugungi vaqtlar', 'Время на сегодня', 'Today\'s time slots'),
              style: const TextStyle(
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 3-column grid; the second row holds a single chip.
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Expanded(child: _slotChip(i, lang)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _slotChip(3, lang)),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotChip(int i, AppLanguage lang) {
    final selected = _slot == i;
    return GestureDetector(
      onTap: () => setState(() => _slot = i),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AppColors.background),
        ),
        child: Text(
          _slots[i],
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF8D96A4),
          ),
        ),
      ),
    );
  }
}

/// A single urgency option row with a radio indicator.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(32),
          border: selected
              ? Border.all(color: const Color(0xFF60A5FA), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: Color(0xFF8D96A4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// 22px radio indicator — filled blue with a white dot when selected.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue,
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
