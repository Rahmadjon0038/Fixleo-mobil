import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_offer_screen.dart';

/// Detail of a single nearby request — full description, photos, address,
/// client and time, with respond / decline actions.
class MasterRequestDetailScreen extends StatelessWidget {
  const MasterRequestDetailScreen({super.key});

  /// Bottom sheet asking for a decline reason; pops the detail on confirm.
  Future<void> _showDeclineSheet(BuildContext context) async {
    final declined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x33797A7E),
      builder: (_) => const _DeclineSheet(),
    );
    if (declined == true && context.mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Buyurtma #1042',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.water_drop_outlined,
                          size: 18,
                          color: AppColors.blue,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Santexnika',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Oshxonada smesitel oqyapti, kartrij almashtirish kerak. '
                    'Zaxira bor.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Photo thumbnails.
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i != 0) const SizedBox(width: 8),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: 'Yunusobod, Amir Temur 12',
                  ),
                  const SizedBox(height: 6),
                  const _InfoRow(
                    icon: Icons.person_outline,
                    text: 'Mijoz — Arslan K.',
                  ),
                  const SizedBox(height: 6),
                  const _InfoRow(
                    icon: Icons.schedule,
                    text: 'Bugun, 12:00–15:00',
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Javob berish',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MasterOfferScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: () => _showDeclineSheet(context),
                child: const Text(
                  'Buyurtmani rad etish',
                  style: TextStyle(fontSize: 16, color: Color(0xFF8D96A4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a decline reason.
class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet();

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  static const _reasons = [
    'Bu vaqtda bandman',
    'Uzoq borish kerak',
    'Mening profilim emas',
    'Past byudjet',
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Buyurtmani rad etish?',
                style: TextStyle(
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF23232E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sababini koʻrsating — bu tanlovga yordam beradi',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _reasons.length; i++) ...[
                      if (i != 0) const SizedBox(height: 8),
                      _ReasonRow(
                        label: _reasons[i],
                        selected: _selected == i,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      label: 'Orqaga',
                      filled: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetButton(
                      label: 'Rad etish',
                      filled: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One decline-reason row — white pill with a radio dot.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.navy),
              ),
            ),
            Container(
              width: 22,
              height: 22,
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
                        width: 7,
                        height: 7,
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

/// Sheet action button — filled blue or light-gray.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.blue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: filled ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

/// Gray icon + gray label row used for address / client / time.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8D96A4)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8D96A4)),
        ),
      ],
    );
  }
}
