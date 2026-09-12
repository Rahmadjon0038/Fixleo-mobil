import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';

/// Step 6 of the "new request" flow — the request is live; we poll for master
/// responses and move to the responses list as soon as any arrive.
class WaitingResponsesScreen extends StatefulWidget {
  const WaitingResponsesScreen({
    super.key,
    required this.orderId,
    this.service,
    this.homeBuilder,
  });

  final int orderId;
  final OrderService? service;
  final WidgetBuilder? homeBuilder;

  @override
  State<WaitingResponsesScreen> createState() => _WaitingResponsesScreenState();
}

class _WaitingResponsesScreenState extends State<WaitingResponsesScreen> {
  static const _blue50 = Color(0xFFEFF6FF);
  static const _blue400 = Color(0xFF60A5FA);
  static const _slate200 = Color(0xFFE2E8F0);

  late final OrderService _orders = widget.service ?? OrderService();
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
    if (mounted) _goHome();
  }

  void _goHome() {
    _timer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: widget.homeBuilder ?? (_) => const HomeScreen(),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: BrandedScaffold(
        title: tr(lang, 'Ariza yuborildi', 'Заявка отправлена', 'Request sent'),
        showBack: true,
        onBack: _goHome,
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
              // "Arizani bekor qilish" — white glass pill with blue text.
              GlassButton(
                label: tr(
                  lang,
                  'Arizani bekor qilish',
                  'Отменить заявку',
                  'Cancel request',
                ),
                height: 52,
                variant: GlassButtonVariant.secondary,
                onPressed: _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          LiquidSurface(
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
    return GlassCard.lite(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar placeholder.
          LiquidSurface(
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
    return LiquidSurface(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
