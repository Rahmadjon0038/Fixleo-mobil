import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/rate_master_screen.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';

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
    this.orderService,
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
  final OrderService? orderService;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _slate300 = Color(0xFFCBD5E1);
  static const _gray = Color(0xFF8D96A4);

  int _selected = 0;
  final PaymentService _payments = PaymentService();
  late final OrderService _orders = widget.orderService ?? OrderService();
  List<SavedCard> _realCards = const [];
  OrderDetail? _order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) {
      _loadCards();
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _orders.detail(widget.orderId!);
      if (mounted) setState(() => _order = order);
    } on ApiException {
      // OrderDoneScreen already passes a real amount/title, so keep those
      // values if a refresh is temporarily unavailable.
    }
  }

  static String _money(int value) {
    final raw = value.toString();
    final formatted = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) formatted.write(' ');
      formatted.write(raw[i]);
    }
    return formatted.toString();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  lang,
                  'Toʻlov amalga oshmadi',
                  'Оплата не прошла',
                  'Payment failed',
                ),
              ),
            ),
          );
          return;
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Toʻlov amalga oshirildi',
              'Оплата выполнена',
              'Payment completed',
            ),
          ),
        ),
      );

    if (widget.onSuccess != null) {
      widget.onSuccess!.call();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RateMasterScreen(orderId: widget.orderId),
      ),
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
            // Built directly on GlassContainer (rather than GlassButton) so
            // the busy state can swap in a spinner, same as before — the
            // tint/opacity values mirror GlassButtonVariant.primary.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Semantics(
                button: true,
                enabled: !_busy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : _pay,
                  child: ExcludeSemantics(
                    child: GlassContainer(
                      tint: AppColors.blue,
                      tintOpacityTop: 0.90,
                      tintOpacityBottom: 0.74,
                      borderOpacity: 0.5,
                      borderRadius: 40,
                      shadow: !_busy,
                      shadowColor: AppColors.blue,
                      alignment: Alignment.center,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.primaryLabel ??
                                  tr(lang, 'Toʻlash', 'Оплатить', 'Pay'),
                              style: const TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                letterSpacing: -0.18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                    ),
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
    final realAmount =
        _order?.paymentAmount ?? _order?.finalAmount ?? _order?.agreedPrice;
    final amount = realAmount == null
        ? widget.amount
        : '${_money(realAmount)} ${tr(lang, 'soʻm', 'сум', 'sum')}';
    final realTitle = _order?.title.trim();
    final subtitle = widget.orderId != null && realTitle?.isNotEmpty == true
        ? '$realTitle · #${widget.orderId}'
        : widget.subtitle;
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(16),
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
            amount,
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
            subtitle,
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
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          if (_realCards.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            ),
          for (var i = 0; i < _realCards.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _cardTile(i),
          ],
        ],
      ),
    );
  }

  Widget _cardTile(int index) {
    final selected = _selected == index;
    final card = _realCards[index];
    final tile = selected
        ? GlassContainer.tinted(
            borderRadius: 32,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: _cardTileContent(card, selected),
          )
        : GlassContainer.lite(
            borderRadius: 32,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: _cardTileContent(card, selected),
          );
    return GestureDetector(
      onTap: () => setState(() => _selected = index),
      child: tile,
    );
  }

  Widget _cardTileContent(SavedCard card, bool selected) {
    return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Karta **** ${card.last4}',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    card.brand.isEmpty ? '—' : card.brand,
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
    return GlassContainer.tinted(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          color: Colors.white,
        ),
      ),
    );
  }
}
