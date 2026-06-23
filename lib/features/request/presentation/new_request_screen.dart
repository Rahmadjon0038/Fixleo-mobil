import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/request/presentation/photo_problem_screen.dart';

/// Step 1 of the "new request" flow — describe the task.
class NewRequestScreen extends StatelessWidget {
  const NewRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Yangi buyurtma',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepProgress(current: 0, total: 4),
            const SizedBox(height: 16),
            const _CategoryPill(label: 'Santexnika'),
            const SizedBox(height: 16),
            const _DescribeCard(),
            const Spacer(),
            PrimaryButton(
              label: 'Keyingi',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhotoProblemScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i != 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= current
                    ? AppColors.blue
                    : AppColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icon/Waterdrop.svg', width: 18, height: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _DescribeCard extends StatelessWidget {
  const _DescribeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vazifani tasvirlang',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const TextField(
              maxLines: 4,
              style: TextStyle(fontSize: 14, color: AppColors.navy),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText:
                    'Masalan: oshxonadagi smesitel oqyapti, kartrijni '
                    'almashtirish kerak...',
                hintStyle: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
