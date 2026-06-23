import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/waiting_responses_screen.dart';

/// Step 5 (final) of the "new request" flow — review the assembled request
/// before sending it out to masters.
class ReviewRequestScreen extends StatelessWidget {
  const ReviewRequestScreen({super.key});

  /// blue/100 from the design system.
  static const _blue100 = Color(0xFFDBEAFE);
  static const _gray = Color(0xFF8D96A4);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Arizani tekshiring',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 11),
                    _hintCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // "Arizani yuborish" — Figma pill: 52px tall, fully rounded.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WaitingResponsesScreen(),
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
                  'Arizani yuborish',
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

  Widget _summaryCard() {
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
          // Category chip.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _blue100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icon/Waterdrop.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.blue,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Santexnika',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Oshxonadagi smesitel oqyapti, kartrijni almashtirish kerak. '
            'Zaxiradagisi bor.',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          // Photo thumbnails (placeholders).
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _blue100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.location_on_outlined,
            'Yunusobod, Amir Temur 12',
          ),
          const SizedBox(height: 6),
          _infoRow(
            Icons.access_time_rounded,
            'Bugun, 12:00–15:00',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _gray),
        const SizedBox(width: 2),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.16,
            color: _gray,
          ),
        ),
      ],
    );
  }

  Widget _hintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'Ustalar javoblarda narx taklif qiladi',
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
