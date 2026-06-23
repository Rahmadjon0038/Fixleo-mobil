import 'package:flutter/material.dart';

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
  static const _options = [
    ('Shoshilinch — hozir', 'Usta bir soat ichida yetib keladi'),
    ('Bugun', 'Qulay vaqtni tanlang'),
    ('Ertaga yoki keyinroq', 'Sanani rejalashtirish'),
  ];

  static const _slots = [
    '10:00–12:00',
    '12:00–15:00',
    '15:00–18:00',
    '18:00–21:00',
  ];

  int _option = 0;
  int _slot = 1;

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Usta qachon kerak',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _optionsCard(),
                    const SizedBox(height: 14),
                    _slotsCard(),
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
                child: const Text(
                  'Davom etish',
                  style: TextStyle(
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

  Widget _optionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _OptionTile(
              title: _options[i].$1,
              subtitle: _options[i].$2,
              selected: _option == i,
              onTap: () => setState(() => _option = i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slotsCard() {
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Bugungi vaqtlar',
              style: TextStyle(
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
                Expanded(child: _slotChip(i)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _slotChip(3)),
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

  Widget _slotChip(int i) {
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
