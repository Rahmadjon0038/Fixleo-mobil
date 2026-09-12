import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/order_status.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

/// "My orders" — the user's orders split into Active and Completed tabs.
/// Live data from `GET /clients/me/orders?status=active|done`.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({
    super.key,
    this.initialTab = 0,
    this.embedded = false,
    this.service,
  });

  /// 0 = Active, 1 = Completed. Profile → "Order history" opens on Completed.
  final int initialTab;
  final bool embedded;
  final OrderService? service;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static const _gray = Color(0xFF8D96A4);
  static const _amber50 = Color(0xFFFFFBEB);
  static const _amber600 = Color(0xFFD97706);
  static const _emerald50 = Color(0xFFECFDF5);
  static const _teal600 = Color(0xFF0D9488);
  static const _red50 = Color(0xFFFEF2F2);
  static const _red600 = Color(0xFFDC2626);

  late final OrderService _service = widget.service ?? OrderService();

  /// 0 = Active, 1 = Completed.
  late int _tab = widget.initialTab;
  List<OrderSummary> _items = const [];
  bool _loading = true;
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
      final items = await _service.list(status: _tab == 0 ? 'active' : 'done');
      if (!mounted) return;
      setState(() {
        _items = items;
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

  void _switchTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;

    return BrandedScaffold(
      title: tr(lang, 'Mening buyurtmalarim', 'Мои заказы', 'My orders'),
      showBack: !widget.embedded,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, widget.embedded ? 100 : 20),
        child: Column(
          children: [
            _tabBar(lang),
            const SizedBox(height: 10),
            Expanded(child: _list(lang)),
          ],
        ),
      ),
    );
  }

  Widget _list(AppLanguage lang) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _placeholder(_error!, retry: true);
    }
    if (_items.isEmpty) {
      return _placeholder(
        tr(
          lang,
          'Hozircha buyurtmalar yoʻq',
          'Пока нет заказов',
          'No orders yet',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _orderCard(_items[index]),
      ),
    );
  }

  Widget _placeholder(String message, {bool retry = false}) {
    final lang = LocaleController.language.value;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _gray),
        ),
        if (retry) ...[
          const SizedBox(height: 12),
          Center(
            child: LiquidActionButton.text(
              onPressed: _load,
              child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
            ),
          ),
        ],
      ],
    );
  }

  String _money(int? v) {
    if (v == null) return '—';
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} сум';
  }

  String _subtitle(OrderSummary o, AppLanguage lang) {
    final who =
        o.masterName ??
        (o.offersCount > 0
            ? tr(
                lang,
                'Takliflar: ${o.offersCount}',
                'Откликов: ${o.offersCount}',
                'Offers: ${o.offersCount}',
              )
            : tr(lang, 'Usta qidirilmoqda', 'Поиск мастера', 'Searching'));
    final d = o.createdAt;
    final date = d == null
        ? ''
        : ' · ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    return '$who$date';
  }

  /// Segmented Active / Completed switch.
  Widget _tabBar(AppLanguage lang) {
    return GlassContainer(
      height: 41,
      padding: const EdgeInsets.all(3),
      borderRadius: 296,
      child: Row(
        children: [
          _tabItem(tr(lang, 'Faol', 'Активные', 'Active'), 0),
          _tabItem(tr(lang, 'Yakunlangan', 'Завершённые', 'Completed'), 1),
        ],
      ),
    );
  }

  Widget _tabItem(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        // Use _switchTab so the list actually refetches for the chosen tab
        // (active vs completed) — a bare setState left the data stale.
        onTap: () => _switchTab(index),
        child: selected
            ? GlassContainer.lite(
                height: 35,
                borderRadius: 20,
                alignment: Alignment.center,
                shadow: false,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              )
            : LiquidSurface(
                height: 35,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: AppColors.navy,
                  ),
                ),
              ),
      ),
    );
  }

  /// One order card: title + master/date on the left, status + price right.
  Widget _orderCard(OrderSummary order) {
    final lang = LocaleController.language.value;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: order.id),
          ),
        );
        if (mounted) _load();
      },
      child: GlassContainer.lite(
        height: 87,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        borderRadius: 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    _subtitle(order, lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusTag(order),
                Text(
                  _money(order.price),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTag(OrderSummary order) {
    final active = !isTerminalOrderStatus(order.status);
    final cancelled = isCancelledOrderStatus(order.status);
    final backgroundColor = active
        ? _amber50
        : cancelled
        ? _red50
        : _emerald50;
    final foregroundColor = active
        ? _amber600
        : cancelled
        ? _red600
        : _teal600;
    return LiquidSurface(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          orderStatusLabel(LocaleController.language.value, order.status),
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            letterSpacing: -0.12,
            fontWeight: FontWeight.w500,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}
