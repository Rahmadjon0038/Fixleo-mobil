import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';

/// Step 6 of the "new request" flow — the request is live; we poll for master
/// responses and move to the responses list as soon as any arrive.
class WaitingResponsesScreen extends StatefulWidget {
  const WaitingResponsesScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<WaitingResponsesScreen> createState() => _WaitingResponsesScreenState();
}

class _WaitingResponsesScreenState extends State<WaitingResponsesScreen> {
  static const _blue50 = Color(0xFFEFF6FF);
  static const _blue400 = Color(0xFF60A5FA);
  static const _slate200 = Color(0xFFE2E8F0);

  final OrderService _orders = OrderService();
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Poll for offers; jump to the responses list once any master replies.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    try {
      final offers = await _orders.offers(widget.orderId);
      if (!mounted || _navigated) return;
      if (offers.isNotEmpty) {
        _navigated = true;
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MastersResponsesScreen(orderId: widget.orderId),
          ),
        );
      }
    } catch (_) {
      // keep waiting; a transient failure shouldn't drop the user out
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    try {
      await _orders.cancel(widget.orderId, reason: 'changed_mind');
    } catch (_) {}
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Ariza yuborildi', 'Заявка отправлена', 'Request sent'),
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
                onPressed: _cancel,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.blue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  tr(
                    lang,
                    'Arizani bekor qilish',
                    'Отменить заявку',
                    'Cancel request',
                  ),
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
          Text(
            tr(
              LocaleController.language.value,
              'Yaqin atrofdagi ustalarni qidiryapmiz',
              'Ищем мастеров поблизости',
              'Searching for nearby masters',
            ),
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              LocaleController.language.value,
              'Odatda javoblar 2–5 daqiqada keladi',
              'Обычно ответы приходят за 2–5 минут',
              'Replies usually arrive in 2–5 minutes',
            ),
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
