import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/master_profile_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

/// Step 7 of the "new request" flow — the live list of masters who responded,
/// each with a price the client can accept (→ assigned) or decline.
class MastersResponsesScreen extends StatefulWidget {
  const MastersResponsesScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<MastersResponsesScreen> createState() => _MastersResponsesScreenState();
}

class _MastersResponsesScreenState extends State<MastersResponsesScreen> {
  static const _gray = Color(0xFF8D96A4);

  final OrderService _orders = OrderService();
  List<OfferView> _offers = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// The order's current status — lets the empty state tell "no offers yet"
  /// apart from "the offers already got resolved" (order moved on, e.g. via
  /// a stale notification tapped after the client already picked a master).
  String? _orderStatus;

  /// Offer ordering — 'rating' (default) or 'price', like the FINAL chip.
  String _sort = 'rating';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toggleSort() {
    setState(() => _sort = _sort == 'rating' ? 'price' : 'rating');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await _orders.offers(widget.orderId, sort: _sort);
      String? status;
      try {
        status = (await _orders.detail(widget.orderId)).status;
      } on ApiException {
        // The offers list is the primary data — a failed status lookup just
        // means the empty state falls back to the generic message.
      }
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _orderStatus = status;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _select(OfferView offer) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _orders.selectOffer(widget.orderId, offer.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _decline(OfferView offer) async {
    try {
      await _orders.declineOffer(widget.orderId, offer.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Takliflar · ${_offers.length}',
        'Отклики · ${_offers.length}',
        'Offers · ${_offers.length}',
      ),
      showBack: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: _gray)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  Row(
                    children: [
                      Text(
                        tr(
                          lang,
                          '${_offers.length} usta taklif qoldirdi',
                          '${_offers.length} мастера откликнулись',
                          '${_offers.length} masters responded',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: -0.16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF23232E),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _toggleSort,
                        child: GlassContainer(
                          borderRadius: 999,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.swap_vert,
                                size: 14,
                                color: _gray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sort == 'rating'
                                    ? tr(
                                        lang,
                                        'Reyting boʻyicha',
                                        'По рейтингу',
                                        'By rating',
                                      )
                                    : tr(
                                        lang,
                                        'Narx boʻyicha',
                                        'По цене',
                                        'By price',
                                      ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: FontWeight.w500,
                                  color: _gray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_offers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _orderStatus != null &&
                                      _orderStatus != 'searching'
                                  ? tr(
                                      lang,
                                      'Bu buyurtma boʻyicha qaror allaqachon qabul qilingan',
                                      'Решение по этому заказу уже принято',
                                      'A decision has already been made for this order',
                                    )
                                  : tr(
                                      lang,
                                      'Hozircha javoblar yoʻq',
                                      'Пока нет ответов',
                                      'No replies yet',
                                    ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _gray),
                            ),
                            if (_orderStatus != null &&
                                _orderStatus != 'searching') ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => OrderTrackingScreen(
                                          orderId: widget.orderId,
                                        ),
                                      ),
                                    ),
                                child: Text(
                                  tr(
                                    lang,
                                    'Buyurtmani ochish',
                                    'Открыть заказ',
                                    'Open order',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  for (var i = 0; i < _offers.length; i++) ...[
                    if (i != 0) const SizedBox(height: 10),
                    _MasterCard(
                      offer: _offers[i],
                      lang: lang,
                      busy: _busy,
                      onSelect: () => _select(_offers[i]),
                      onDecline: () => _decline(_offers[i]),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({
    required this.offer,
    required this.lang,
    required this.busy,
    required this.onSelect,
    required this.onDecline,
  });

  final OfferView offer;
  final AppLanguage lang;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onDecline;

  static const _gray = Color(0xFF8D96A4);
  static const _slate100 = Color(0xFFF1F5F9);

  String get _rating {
    final parts = <String>[
      if (offer.ratingAvg != null) offer.ratingAvg!.toStringAsFixed(1),
      tr(
        lang,
        '${offer.ratingCount} sharh',
        '${offer.ratingCount} отзыва',
        '${offer.ratingCount} reviews',
      ),
      '${offer.distanceKm.toStringAsFixed(1)} ${tr(lang, 'km', 'км', 'km')}',
    ];
    return parts.join(' · ');
  }

  String get _price {
    if (offer.priceType == 'after_inspection' || offer.price == null) {
      return tr(lang, 'koʻrikdan keyin', 'после осмотра', 'after inspection');
    }
    final s = offer.price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Repeated card in a scrolling list — .lite skips BackdropFilter.
    return GlassCard.lite(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MasterProfileScreen(masterId: offer.masterId),
                  ),
                ),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person, size: 26, color: _gray),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.masterName ?? tr(lang, 'Usta', 'Мастер', 'Master'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _rating,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              color: _gray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tr(lang, 'dan', 'от', 'from'),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: _gray,
                    ),
                  ),
                  Text(
                    _price,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 24 / 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (offer.comment != null && offer.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                offer.comment!,
                style: const TextStyle(fontSize: 13, color: _gray),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _cardButton(
            label: tr(lang, 'Tanlash', 'Выбрать', 'Select'),
            background: AppColors.blue,
            foreground: Colors.white,
            onTap: busy ? null : onSelect,
          ),
          const SizedBox(height: 12),
          _cardButton(
            label: tr(lang, 'Bekor qilish', 'Отменить', 'Cancel'),
            background: _slate100,
            foreground: AppColors.blue,
            onTap: busy ? null : onDecline,
          ),
        ],
      ),
    );
  }

  Widget _cardButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      // Repeated per-row action inside an already-.lite card — .lite again
      // keeps this cheap across a long list of offers.
      child: GlassContainer.lite(
        tint: background,
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 22 / 16,
            letterSpacing: -0.18,
            fontWeight: FontWeight.w500,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
