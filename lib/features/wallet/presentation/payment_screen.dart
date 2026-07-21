import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/presentation/rate_master_screen.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';

/// A saved payment card option.
class _Card {
  const _Card({required this.number, required this.brand});

  final String number;
  final String brand;
}

/// Shared payment screen for:
/// - order payment in the client flow;
/// - wallet top-up from the balance screen.
///
/// The screen stays mock-driven for now, but the layout is reusable and the
/// success action can be customized per entry point.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    this.orderId,
    this.title,
    this.amountLabel,
    this.amount = '60 000 soʻm',
    this.subtitle = 'Smesitel almashtirish · buyurtma #1024',
    this.primaryLabel,
    this.onSuccess,
  });

  /// When set, this is a real order payment (`POST /clients/me/orders/:id/pay`).
  final int? orderId;

  /// Optional title for the top pill.
  final String? title;

  /// Small label above the amount, e.g. "K toʻlov" or "Balansni toʻldirish".
  final String? amountLabel;

  /// Amount shown in the header card.
  final String amount;

  /// Smaller descriptive line under the amount.
  final String subtitle;

  /// Optional label for the primary action button.
  final String? primaryLabel;

  /// Optional custom success action.
  /// When absent, the existing order-payment flow continues to rating.
  final VoidCallback? onSuccess;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _blue100 = Color(0xFFDBEAFE);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _gray = Color(0xFF8D96A4);

  static const _cards = <_Card>[
    _Card(number: 'Karta **** 4267', brand: 'Visa'),
    _Card(number: 'Karta **** 4267', brand: 'Uzcard'),
    _Card(number: 'Karta **** 4267', brand: 'Humo'),
  ];

  int _selected = 0;
  final PaymentService _payments = PaymentService();
  List<SavedCard> _realCards = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      var cards = await _payments.cards();
      if (cards.isEmpty) {
        // Auto-provision a test card so the flow works end-to-end (mock provider).
        cards = [await _payments.addCard(brand: 'uzcard', last4: '4242')];
      }
      if (mounted) setState(() => _realCards = cards);
    } on ApiException {
      // fall back to the mock card list for display
    }
  }

  Future<void> _pay() async {
    final lang = LocaleController.language.value;

    // Real order payment.
    if (widget.orderId != null) {
      if (_realCards.isEmpty) {
        await _loadCards();
        if (_realCards.isEmpty) return;
      }
      setState(() => _busy = true);
      try {
        final card = _realCards[_selected.clamp(0, _realCards.length - 1)];
        final status = await _payments.pay(widget.orderId!, card.id);
        if (!mounted) return;
        setState(() => _busy = false);
        if (status != 'succeeded') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(lang, 'Toʻlov amalga oshmadi', 'Оплата не прошла', 'Payment failed'))));
          return;
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr(lang, 'Toʻlov amalga oshirildi', 'Оплата выполнена', 'Payment completed')),
      ));

    if (widget.onSuccess != null) {
      widget.onSuccess!.call();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RateMasterScreen(orderId: widget.orderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: widget.title ?? tr(lang, 'Toʻlov', 'Оплата', 'Payment'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _amountCard(lang),
                    const SizedBox(height: 10),
                    _methodsCard(lang),
                    const SizedBox(height: 10),
                    _infoBanner(lang),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _pay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  widget.primaryLabel ??
                      tr(lang, 'Toʻlash', 'Оплатить', 'Pay'),
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

  Widget _amountCard(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Text(
            widget.amountLabel ?? tr(lang, 'Toʻlovga', 'К оплате', 'To pay'),
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              color: _gray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.amount,
            style: const TextStyle(
              fontSize: 32,
              height: 38 / 32,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
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

  Widget _methodsCard(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Toʻlov usuli', 'Способ оплаты', 'Payment method'),
            style: const TextStyle(
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _cards.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _cardTile(i),
          ],
        ],
      ),
    );
  }

  Widget _cardTile(int index) {
    final selected = _selected == index;
    final card = _cards[index];
    return GestureDetector(
      onTap: () => setState(() => _selected = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _slate100 : _slate50,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.number,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    card.brand,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
            _radio(selected),
          ],
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: selected ? null : Border.all(color: _slate300, width: 2),
      ),
      child: selected
          ? const Center(
              child: Icon(Icons.circle, size: 7, color: Colors.white),
            )
          : null,
    );
  }

  Widget _infoBanner(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tr(
          lang,
          'Pul faqat ish bajarilgani tasdiqlangandan soʻng yechiladi.',
          'Списание только после подтверждения выполнения работы.',
          'Money is charged only after the work is confirmed.',
        ),
        style: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
