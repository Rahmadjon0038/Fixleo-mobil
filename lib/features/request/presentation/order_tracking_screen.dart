import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/order_status_screen.dart';

/// Live order tracking — a map preview, a 4-step progress bar, the assigned
/// master and the order details. Live data from `GET /clients/me/orders/:id`.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final int orderId;

  static const _sky50 = Color(0xFFF0F9FF);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _text = Color(0xFF23232E);
  static const _muted = Color(0xFF9494A3);
  static const _gray = Color(0xFF8D96A4);
  static const _mapBg = Color(0xFFE8EFF6);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const _sky50 = OrderTrackingScreen._sky50;
  static const _slate200 = OrderTrackingScreen._slate200;
  static const _text = OrderTrackingScreen._text;
  static const _muted = OrderTrackingScreen._muted;
  static const _gray = OrderTrackingScreen._gray;
  static const _mapBg = OrderTrackingScreen._mapBg;

  final OrderService _service = OrderService();
  OrderDetail? _order;
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
      final order = await _service.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
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

  /// 0..4 — how many of the four tracking steps are complete.
  int get _doneSteps => switch (_order?.status) {
        'assigned' => 1,
        'on_the_way' => 2,
        'arrived' => 3,
        'work_done' || 'completed' || 'disputed' => 4,
        _ => 0,
      };

  String _statusText(AppLanguage lang) => switch (_order?.status) {
        'searching' => tr(lang, 'Usta qidirilmoqda', 'Поиск мастера', 'Searching for a master'),
        'assigned' => tr(lang, 'Usta tayinlandi', 'Мастер назначен', 'Master assigned'),
        'on_the_way' => tr(lang, 'Usta yoʻlda', 'Мастер в пути', 'Master on the way'),
        'arrived' => tr(lang, 'Usta yetib keldi', 'Мастер на месте', 'Master arrived'),
        'work_done' => tr(lang, 'Ish bajarildi', 'Работа выполнена', 'Work done'),
        'completed' => tr(lang, 'Yakunlandi', 'Завершён', 'Completed'),
        _ => tr(lang, 'Buyurtma', 'Заказ', 'Order'),
      };

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

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final order = _order;
    return BrandedScaffold(
      title: tr(lang, 'Buyurtma №${widget.orderId}', 'Заказ №${widget.orderId}',
          'Order No. ${widget.orderId}'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _gray)),
                        TextButton(
                          onPressed: _load,
                          child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                _trackingCard(),
                                const SizedBox(height: 10),
                                if (order?.master != null) ...[
                                  _masterCard(context, lang),
                                  const SizedBox(height: 10),
                                ],
                                _detailsCard(lang),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderStatusScreen(orderId: widget.orderId),
                              ),
                            );
                            if (mounted) _load();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          child: Text(
                            tr(lang, 'Buyurtma statusiga oʻtish', 'Перейти к статусу заказа',
                                'Go to order status'),
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

  /// Map preview + status line + 4-step progress.
  Widget _trackingCard() {
    final lang = LocaleController.language.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _mapPreview(),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: Row(
                  children: [
                    const _Dot(),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _statusText(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 22 / 16,
                          letterSpacing: -0.18,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sky50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_doneSteps}/4',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _progressBar(),
        ],
      ),
    );
  }

  /// Lightweight stylised map preview with a centred location pin.
  Widget _mapPreview() {
    return Container(
      height: 116,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mapBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapLinesPainter()),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 34, color: AppColors.blue),
              Container(
                width: 16,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4-step connected progress, driven by the live order status.
  Widget _progressBar() {
    final d = _doneSteps;
    return Row(
      children: [
        _stepNode(done: d >= 1, label: '1'),
        _connector(blue: d >= 2),
        _stepNode(done: d >= 2, label: '2'),
        _connector(blue: d >= 3),
        _stepNode(done: d >= 3, label: '3'),
        _connector(blue: d >= 4),
        _stepNode(done: d >= 4, label: '4'),
      ],
    );
  }

  Widget _stepNode({required bool done, String? label}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? AppColors.blue : _slate200,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(
              label ?? '',
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.16,
                color: _gray,
              ),
            ),
    );
  }

  Widget _connector({required bool blue}) {
    return Expanded(
      child: Container(height: 3, color: blue ? AppColors.blue : _slate200),
    );
  }

  /// Assigned master: avatar, name + role. Tapping it opens the chat.
  Widget _masterCard(BuildContext context, AppLanguage lang) {
    final m = _order?.master;
    final conversationId = _order?.conversationId;
    final rating = m?.ratingAvg;
    final subtitle = [
      if (m?.categoryName != null && m!.categoryName!.isNotEmpty) m.categoryName!,
      if (rating != null) rating.toStringAsFixed(1),
    ].join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: conversationId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: conversationId,
                      peerName: m?.name,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline, size: 26, color: _gray),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m?.name ?? tr(lang, 'Usta', 'Мастер', 'Master'),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: -0.16,
                          color: _muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (conversationId != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _sky50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: AppColors.blue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Order summary rows.
  Widget _detailsCard(AppLanguage lang) {
    final o = _order;
    final price = o?.finalAmount ?? o?.agreedPrice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _DetailRow(
              label: tr(lang, 'Xizmat', 'Услуга', 'Service'),
              value: o?.title ?? '—'),
          const SizedBox(height: 8),
          _DetailRow(
              label: tr(lang, 'Manzil', 'Адрес', 'Address'),
              value: o?.addressText ?? '—'),
          if (o?.slotLabel != null) ...[
            const SizedBox(height: 8),
            _DetailRow(label: tr(lang, 'Vaqt', 'Время', 'Time'), value: o!.slotLabel!),
          ],
          const SizedBox(height: 8),
          _DetailRow(
              label: tr(lang, 'Narx', 'Цена', 'Price'),
              value: price != null
                  ? _money(price)
                  : tr(lang, 'Otkliklar boʻyicha', 'по откликам', 'by offers')),
        ],
      ),
    );
  }
}

/// Faint "street" lines that give the map preview a city-map texture.
class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // A couple of diagonal + cross streets.
    canvas.drawLine(Offset(0, h * 0.35), Offset(w, h * 0.55), paint);
    canvas.drawLine(Offset(w * 0.25, 0), Offset(w * 0.45, h), paint);
    canvas.drawLine(Offset(w * 0.7, 0), Offset(w * 0.85, h), paint);
    canvas.drawLine(Offset(0, h * 0.78), Offset(w, h * 0.7), paint);
  }

  @override
  bool shouldRepaint(_MapLinesPainter oldDelegate) => false;
}

/// Small blue status dot next to the tracking title.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A "label … value" row of the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: OrderTrackingScreen._muted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: OrderTrackingScreen._text,
            ),
          ),
        ),
      ],
    );
  }
}
