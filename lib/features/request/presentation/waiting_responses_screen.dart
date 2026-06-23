import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';

/// Step 6 of the "new request" flow — the request has been sent and we are
/// waiting for masters nearby to respond. After a short delay (simulating
/// incoming responses) it advances to the masters list.
class WaitingResponsesScreen extends StatefulWidget {
  const WaitingResponsesScreen({super.key});

  @override
  State<WaitingResponsesScreen> createState() => _WaitingResponsesScreenState();
}

class _WaitingResponsesScreenState extends State<WaitingResponsesScreen> {
  static const _blue50 = Color(0xFFEFF6FF);
  static const _blue400 = Color(0xFF60A5FA);
  static const _slate200 = Color(0xFFE2E8F0);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulate masters responding after a few seconds.
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MastersResponsesScreen()),
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
      title: 'Ariza yuborildi',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _statusCard(),
                    const SizedBox(height: 10),
                    _skeletonCard(),
                    const SizedBox(height: 10),
                    _skeletonCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // "Arizani bekor qilish" — white pill with blue text.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.blue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'Arizani bekor qilish',
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

  Widget _statusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
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
              color: _blue50,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icon/search.svg',
                width: 30,
                height: 30,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Yaqin atrofdagi ustalarni qidiryapmiz',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Odatda javoblar 2–5 daqiqada keladi',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: _blue400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          // Avatar placeholder.
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _slate200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bar(width: 160),
              SizedBox(height: 8),
              _Bar(width: 100),
            ],
          ),
        ],
      ),
    );
  }
}

/// A grey skeleton bar (loading placeholder).
class _Bar extends StatelessWidget {
  const _Bar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
