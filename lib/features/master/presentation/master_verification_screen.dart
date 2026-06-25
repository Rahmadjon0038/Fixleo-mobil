import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/master/presentation/master_verified_screen.dart';

/// Verification status — shown after the selfie step while the moderator
/// reviews the master's documents. After a short wait it advances to the
/// "verified" success screen automatically.
class MasterVerificationScreen extends StatefulWidget {
  const MasterVerificationScreen({super.key});

  @override
  State<MasterVerificationScreen> createState() =>
      _MasterVerificationScreenState();
}

class _MasterVerificationScreenState extends State<MasterVerificationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MasterVerifiedScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Tekshiruv',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            // Header card — animated-looking clock + status text.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.history,
                      size: 34,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Hujjatlar tekshiruvda',
                    style: TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    'Odatda 24 soat davom etadi',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Status checklist.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: const [
                  _StatusRow(
                    icon: Icons.verified,
                    label: 'Pasport yuklandi',
                    done: true,
                  ),
                  _StatusRow(
                    icon: Icons.verified,
                    label: 'Selfi yuklandi',
                    done: true,
                  ),
                  _StatusRow(
                    icon: Icons.schedule,
                    label: 'Moderator qarori',
                    done: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One verification step — blue check when done, gray clock when pending.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.done,
  });

  final IconData icon;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.blue : const Color(0xFF8D96A4);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w500,
              color: done ? AppColors.navy : const Color(0xFF8D96A4),
            ),
          ),
        ],
      ),
    );
  }
}
