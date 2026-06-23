import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/confirmation_screen.dart';

/// Master profile — opened when the user taps "Tanlash" on a response.
/// Shows the master's stats, bio and reviews before final confirmation.
class MasterProfileScreen extends StatelessWidget {
  const MasterProfileScreen({super.key});

  static const _blue100 = Color(0xFFDBEAFE);
  static const _gray = Color(0xFF8D96A4);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Usta',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _profileCard(),
                    const SizedBox(height: 10),
                    _aboutCard(),
                    const SizedBox(height: 10),
                    _reviewsCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // "Ustani tanlash" — Figma pill: 52px tall, fully rounded.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConfirmationScreen(),
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
                  'Ustani tanlash',
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

  Widget _profileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 61,
                height: 61,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person, size: 33, color: _gray),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Aleksey Ivanov',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 24 / 20,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _badge('Top usta'),
                        const SizedBox(width: 6),
                        _badge('4.9', leadingStar: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _Stat(value: '124', label: 'buyurtma'),
              _Stat(value: '98%', label: 'bajarilgan'),
              _Stat(value: '5 yil', label: 'tajriba'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, {bool leadingStar = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: leadingStar ? 8 : 10,
        vertical: leadingStar ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingStar) ...[
            const Icon(Icons.star_rounded, size: 16, color: AppColors.blue),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return _textCard(
      title: 'Usta haqida',
      body: '5 yillik tajribaga ega santexnik. Smesitel, quvurlarni almashtirish, '
          'oqishlarni bartaraf etish. Ozoda va oʻz vaqtida.',
    );
  }

  Widget _reviewsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Sharhlar',
                style: TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Spacer(),
              Text(
                '124',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: _gray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '«Oʻz vaqtida keldi, hammasini ozoda qildi. Tavsiya qilaman!» — Dilshod R.',
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

  Widget _textCard({required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
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
}

/// One of the three centered profile stats (value over label).
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: MasterProfileScreen._gray,
            ),
          ),
        ],
      ),
    );
  }
}
