import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/order_status.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';
import 'package:fixleo/features/request/presentation/chat_screen.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';
import 'package:fixleo/features/request/presentation/order_declined_screen.dart';
import 'package:fixleo/features/request/presentation/order_status_screen.dart';

/// Live order tracking — a map preview, a 4-step progress bar, the assigned
/// master and the order details. Live data from `GET /clients/me/orders/:id`.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.orderService,
  });

  final int orderId;
  final OrderService? orderService;

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

  late final OrderService _service = widget.orderService ?? OrderService();
  OrderDetail? _order;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  StreamSubscription<ClientOrderRealtimeEvent>? _orderEventsSubscription;
  bool _declineScreenShown = false;

  @override
  void initState() {
    super.initState();
    _orderEventsSubscription = AppPresenceService.instance.orderUpdates.listen(
      _handleOrderEvent,
    );
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshSilently(),
    );
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
      if (isTerminalOrderStatus(order.status)) {
        _refreshTimer?.cancel();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted || _loading) return;
    try {
      final previousStatus = _order?.status;
      final order = await _service.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
      });
      if (previousStatus != null &&
          previousStatus != 'searching' &&
          order.status == 'searching') {
        await _showMasterDeclined(canChooseAnotherMaster: true);
        return;
      }
      if (isTerminalOrderStatus(order.status)) {
        _refreshTimer?.cancel();
      }
    } on ApiException {
      // Keep the last successfully rendered status during a transient outage.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _orderEventsSubscription?.cancel();
    super.dispose();
  }

  void _handleOrderEvent(ClientOrderRealtimeEvent event) {
    if (event.orderId != widget.orderId || !mounted) return;
    if (event.kind == ClientOrderEventKind.reopened) {
      unawaited(_showMasterDeclined(canChooseAnotherMaster: true));
      return;
    }
    if (event.to == 'cancelled_by_master') {
      unawaited(_showMasterDeclined(canChooseAnotherMaster: false));
      return;
    }
    unawaited(_refreshSilently());
  }

  Future<void> _showMasterDeclined({
    required bool canChooseAnotherMaster,
  }) async {
    if (!mounted || _declineScreenShown) return;
    _declineScreenShown = true;
    _refreshTimer?.cancel();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDeclinedScreen(
          orderId: widget.orderId,
          canChooseAnotherMaster: canChooseAnotherMaster,
        ),
      ),
    );
  }

  /// 0..4 — how many of the four tracking steps are complete.
  int get _doneSteps => switch (_order?.status) {
    'assigned' => 1,
    'on_the_way' => 2,
    'arrived' => 3,
    'work_done' || 'completed' || 'disputed' => 4,
    _ => 0,
  };

  String _statusText(AppLanguage lang) =>
      orderStatusLabel(lang, _order?.status ?? '');

  Future<void> _handlePrimaryAction() async {
    final status = _order?.status ?? '';
    if (isCancelledOrderStatus(status) || status == 'expired') {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => status == 'searching'
            ? MastersResponsesScreen(orderId: widget.orderId)
            : OrderStatusScreen(orderId: widget.orderId),
      ),
    );
    if (mounted) await _load();
  }

  String _primaryActionLabel(AppLanguage language) {
    final status = _order?.status ?? '';
    if (isCancelledOrderStatus(status) || status == 'expired') {
      return tr(
        language,
        'Bosh sahifaga qaytish',
        'Вернуться на главную',
        'Return home',
      );
    }
    if (status == 'searching') {
      return tr(
        language,
        'Ustani tanlash',
        'Выбрать мастера',
        'Choose a master',
      );
    }
    return tr(
      language,
      'Buyurtma statusiga oʻtish',
      'Перейти к статусу заказа',
      'Go to order status',
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

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final order = _order;
    return BrandedScaffold(
      title: tr(
        lang,
        'Buyurtma №${widget.orderId}',
        'Заказ №${widget.orderId}',
        'Order No. ${widget.orderId}',
      ),
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
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _gray),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: Text(
                        tr(lang, 'Qayta urinish', 'Повторить', 'Retry'),
                      ),
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
                  GlassButton(
                    label: _primaryActionLabel(lang),
                    height: 52,
                    onPressed: _handlePrimaryAction,
                  ),
                ],
              ),
      ),
    );
  }

  /// Map preview + status line + 4-step progress.
  Widget _trackingCard() {
    final lang = LocaleController.language.value;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _mapPreview(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: _Dot(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _statusText(lang),
                        softWrap: true,
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
              const SizedBox(width: 10),
              GlassContainer.lite(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                borderRadius: 999,
                tint: AppColors.blue,
                tintOpacityTop: 0.14,
                tintOpacityBottom: 0.08,
                borderOpacity: 0.3,
                child: Text(
                  '$_doneSteps/4',
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

  /// Real OpenStreetMap preview centred on the order's saved coordinates.
  Widget _mapPreview() {
    final latitude = _order?.latitude;
    final longitude = _order?.longitude;
    final validCoordinates =
        latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180 &&
        !(latitude == 0 && longitude == 0);

    if (!validCoordinates) {
      final lang = LocaleController.language.value;
      return Container(
        height: 140,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _mapBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 30, color: _gray),
            const SizedBox(height: 6),
            Text(
              tr(
                lang,
                'Lokatsiya mavjud emas',
                'Локация недоступна',
                'Location unavailable',
              ),
              style: const TextStyle(fontSize: 13, color: _gray),
            ),
          ],
        ),
      );
    }

    final center = gmap.LatLng(latitude, longitude);
    return Container(
      height: 140,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mapBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IgnorePointer(
        child: gmap.GoogleMap(
          initialCameraPosition: gmap.CameraPosition(target: center, zoom: 15),
          markers: {
            gmap.Marker(
              markerId: const gmap.MarkerId('order-location'),
              position: center,
            ),
          },
          compassEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: false,
        ),
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
      if (m?.categoryName != null && m!.categoryName!.isNotEmpty)
        m.categoryName!,
      if (rating != null) rating.toStringAsFixed(1),
    ].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: conversationId == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    conversationId: conversationId,
                    peerName: m?.name,
                    peerAvatarUrl: m?.avatarUrl,
                  ),
                ),
              );
            },
      child: GlassCard(
        radius: 20,
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
    );
  }

  /// Order summary rows.
  Widget _detailsCard(AppLanguage lang) {
    final o = _order;
    final price = o?.finalAmount ?? o?.agreedPrice;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _DetailRow(
            label: tr(lang, 'Xizmat', 'Услуга', 'Service'),
            value: o?.title ?? '—',
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: tr(lang, 'Manzil', 'Адрес', 'Address'),
            value: o?.addressText ?? '—',
          ),
          if (o != null && o.timing.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: tr(lang, 'Vaqt', 'Время', 'Time'),
              value: orderTimingLabel(
                lang,
                timing: o.timing,
                scheduledDate: o.scheduledDate,
                slotLabel: o.slotLabel,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _DetailRow(
            label: tr(lang, 'Narx', 'Цена', 'Price'),
            value: price != null
                ? _money(price)
                : tr(lang, 'Takliflar boʻyicha', 'по откликам', 'by offers'),
          ),
        ],
      ),
    );
  }
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
