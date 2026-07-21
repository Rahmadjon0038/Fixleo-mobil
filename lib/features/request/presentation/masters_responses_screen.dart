import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
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
  static const _slate100 = Color(0xFFF1F5F9);

  final OrderService _orders = OrderService();
  List<OfferView> _offers = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await _orders.offers(widget.orderId);
      if (!mounted) return;
      setState(() {
        _offers = offers;
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
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: widget.orderId)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _decline(OfferView offer) async {
    try {
      await _orders.declineOffer(widget.orderId, offer.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Javoblar · ${_offers.length}', 'Ответы · ${_offers.length}',
          'Replies · ${_offers.length}'),
      showBack: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: _gray)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      Row(
                        children: [
                          Text(
                            tr(lang, '${_offers.length} usta javob berdi',
                                '${_offers.length} мастеров ответили', '${_offers.length} masters responded'),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              letterSpacing: -0.16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF23232E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_offers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              tr(lang, 'Hozircha javoblar yoʻq', 'Пока нет ответов', 'No replies yet'),
                              style: const TextStyle(color: _gray),
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
      tr(lang, '${offer.ratingCount} sharh', '${offer.ratingCount} отзыва',
          '${offer.ratingCount} reviews'),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MasterProfileScreen(masterId: offer.masterId),
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
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.blue),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _rating,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 20 / 14, color: _gray),
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
                  Text(tr(lang, 'dan', 'от', 'from'),
                      style: const TextStyle(fontSize: 14, height: 20 / 14, color: _gray)),
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
              child: Text(offer.comment!,
                  style: const TextStyle(fontSize: 13, color: _gray)),
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
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
