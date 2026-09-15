import 'dart:async';

import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/location/device_location_feedback.dart';
import 'package:fixleo/core/location/device_location_service.dart';
import 'package:fixleo/core/location/master_trip_tracking_service.dart';
import 'package:fixleo/core/location/navigation_launcher.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_order_completion_screen.dart';

/// The master drives the live order status machine here — on_the_way → arrived
/// → complete (POST /masters/me/orders/:id/status + /complete).
class MasterOrderStatusScreen extends StatefulWidget {
  const MasterOrderStatusScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<MasterOrderStatusScreen> createState() =>
      _MasterOrderStatusScreenState();
}

class _MasterOrderStatusScreenState extends State<MasterOrderStatusScreen>
    with WidgetsBindingObserver {
  static const _terminalStatuses = {
    'completed',
    'disputed',
    'cancelled_by_client',
    'cancelled_by_master',
    'expired',
  };

  final MasterMarketplaceService _market = MasterMarketplaceService();
  final DeviceLocationService _deviceLocation = DeviceLocationService();
  final MasterTripTrackingService _tripTracking =
      MasterTripTrackingService.instance;
  final NavigationLauncher _navigation = const NavigationLauncher();
  MasterOrderDetail? _order;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  Timer? _refreshTimer;
  StreamSubscription<ClientOrderRealtimeEvent>? _orderSubscription;

  /// A finished/cancelled/expired order has nothing left to "advance" —
  /// notification taps (payment received, order completed, ...) land here
  /// for orders in exactly this state, so the advance button needs to stay
  /// hidden instead of offering to re-run the completion flow.
  bool get _isTerminal => _terminalStatuses.contains(_order?.status);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orderSubscription = AppPresenceService.instance.orderUpdates.listen(
      _handleOrderEvent,
    );
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshSilently(),
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final o = await _market.orderDetail(widget.orderId);
      if (mounted) _applyOrder(o, loading: false);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = tr(
            LocaleController.language.value,
            'Buyurtmani yuklab bo‘lmadi',
            'Не удалось загрузить заказ',
            'Could not load the order',
          );
        });
      }
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted || _loading || _busy || _isTerminal) return;
    try {
      final order = await _market.orderDetail(widget.orderId);
      if (mounted) _applyOrder(order);
    } on Object {
      // Preserve the latest rendered state during a temporary outage.
    }
  }

  void _applyOrder(MasterOrderDetail order, {bool? loading}) {
    setState(() {
      _order = order;
      _loadError = null;
      if (loading != null) _loading = loading;
    });
    if (order.status != 'on_the_way' &&
        _tripTracking.state.value.orderId == widget.orderId) {
      unawaited(_tripTracking.stop());
    }
    if (_terminalStatuses.contains(order.status)) _refreshTimer?.cancel();
  }

  void _handleOrderEvent(ClientOrderRealtimeEvent event) {
    if (!mounted || event.orderId != widget.orderId) return;
    if (event.kind == ClientOrderEventKind.cancelled) {
      unawaited(_tripTracking.stop());
    }
    unawaited(_refreshSilently());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(MasterTripTrackingService.instance.syncForCurrentSession());
    unawaited(_refreshSilently());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    unawaited(_orderSubscription?.cancel());
    super.dispose();
  }

  /// Timeline index from the live status.
  int get _selectedIndex => switch (_order?.status) {
    'assigned' => 0,
    'on_the_way' => 1,
    'arrived' => 2,
    'work_done' || 'completed' || 'disputed' => 3,
    _ => 0,
  };

  Future<void> _advance() async {
    final o = _order;
    if (o == null || _busy || _isTerminal) return;
    if (o.status == 'assigned' && !await _confirmJourneyStart()) return;
    setState(() => _busy = true);
    try {
      if (o.status == 'assigned') {
        final initialPosition = await _tripTracking.ensureReady();
        final u = await _market.setStatus(widget.orderId, 'on_the_way');
        await _tripTracking.start(
          orderId: widget.orderId,
          initialPosition: initialPosition,
        );
        if (mounted) {
          setState(() {
            _order = u;
            _busy = false;
          });
          await _showNavigatorPicker();
        }
      } else if (o.status == 'on_the_way') {
        final u = await _market.setStatus(widget.orderId, 'arrived');
        await _tripTracking.stop();
        if (mounted) {
          setState(() {
            _order = u;
            _busy = false;
          });
        }
      } else {
        // arrived → complete the job
        if (!mounted) return;
        setState(() => _busy = false);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MasterOrderCompletionScreen(orderId: widget.orderId),
          ),
        );
        if (mounted) _load();
      }
    } on DeviceLocationException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showDeviceLocationFailure(context, e, _deviceLocation);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _showJourneyError();
    }
  }

  Future<void> _respondInvitation(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _market.respondToInvitation(
        widget.orderId,
        accept: accept,
      );
      if (!mounted) return;
      if (!accept || updated == null) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _order = updated;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<bool> _confirmJourneyStart() async {
    final lang = LocaleController.language.value;
    return await showGlassModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _JourneyConsentSheet(language: lang),
        ) ??
        false;
  }

  Future<void> _resumeTracking() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final initialPosition = await _tripTracking.ensureReady();
      await _tripTracking.start(
        orderId: widget.orderId,
        initialPosition: initialPosition,
      );
      if (!mounted) return;
      setState(() => _busy = false);
    } on DeviceLocationException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showDeviceLocationFailure(context, e, _deviceLocation);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _showJourneyError();
    }
  }

  void _showJourneyError() {
    final lang = LocaleController.language.value;
    AppFeedback.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            lang,
            'Lokatsiyani ishga tushirib bo\u02bblmadi. Qayta urinib ko\u02bbring.',
            'Не удалось запустить геолокацию. Попробуйте ещё раз.',
            'Could not start location sharing. Please try again.',
          ),
        ),
      ),
    );
  }

  Future<void> _showNavigatorPicker() async {
    final o = _order;
    if (o == null || o.latitude == 0 || o.longitude == 0 || !mounted) return;
    final lang = LocaleController.language.value;
    await showGlassModalBottomSheet<void>(
      context: context,
      builder: (context) => _NavigatorSheet(
        language: lang,
        onSelected: (app) {
          Navigator.of(context).pop();
          unawaited(_openNavigator(app));
        },
      ),
    );
  }

  Future<void> _openNavigator(NavigationApp app) async {
    final o = _order;
    if (o == null) return;
    var opened = false;
    try {
      opened = await _navigation.open(
        app,
        latitude: o.latitude,
        longitude: o.longitude,
      );
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      final lang = LocaleController.language.value;
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Tanlangan navigator telefonda topilmadi',
              'Выбранный навигатор не найден на телефоне',
              'The selected navigator is not installed',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final statuses = _statuses(lang);
    if (_loading || _order == null) {
      return BrandedScaffold(
        title: tr(lang, 'Buyurtma holati', 'Статус заказа', 'Order status'),
        showBack: true,
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 42,
                        color: Color(0xFF8D96A4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _loadError ??
                            tr(
                              lang,
                              'Buyurtmani yuklab boʻlmadi',
                              'Не удалось загрузить заказ',
                              'Could not load the order',
                            ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF8D96A4)),
                      ),
                      const SizedBox(height: 8),
                      LiquidActionButton.text(
                        onPressed: _load,
                        child: Text(
                          tr(lang, 'Qayta urinish', 'Повторить', 'Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    final o = _order!;
    return BrandedScaffold(
      title:
          tr(lang, 'Buyurtma', 'Заказ', 'Order') +
          (o.id != 0 ? ' #${o.id}' : ''),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // What the order is actually about — title/address/price
                    // — so a notification tap ("payment received", "order
                    // completed") lands on something specific to that order,
                    // not just a bare status tracker.
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          if (o.clientName?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            _InfoLine(
                              icon: Icons.person_outline,
                              text:
                                  '${tr(lang, 'Mijoz', 'Клиент', 'Client')} — ${o.clientName}',
                            ),
                          ],
                          const SizedBox(height: 6),
                          _InfoLine(
                            icon: Icons.location_on_outlined,
                            text: o.addressText,
                          ),
                          if (o.price != null) ...[
                            const SizedBox(height: 6),
                            _InfoLine(
                              icon: Icons.payments_outlined,
                              text:
                                  '${o.price} ${tr(lang, 'soʻm', 'сум', 'sum')}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (o.invitationPending) ...[
                      const SizedBox(height: 10),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_available_rounded,
                                  color: AppColors.blue,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    tr(
                                      lang,
                                      'Mijoz sizni tanladi',
                                      'Клиент выбрал вас',
                                      'The client chose you',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Text(
                              o.scheduledAt == null
                                  ? tr(
                                      lang,
                                      'Rejalashtirilgan buyurtma',
                                      'Запланированный заказ',
                                      'Scheduled order',
                                    )
                                  : '${MaterialLocalizations.of(context).formatFullDate(o.scheduledAt!.toLocal())}'
                                        ' · ${TimeOfDay.fromDateTime(o.scheduledAt!.toLocal()).format(context)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              tr(
                                lang,
                                'Qabul qilsangiz, buyurtma faollashadi va mijoz bilan chat ochiladi.',
                                'После принятия заказ станет активным и откроется чат с клиентом.',
                                'Accept to activate the order and open the client chat.',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // The step-by-step tracker only means something for a
                    // job still in progress — a "payment received"/"order
                    // completed" notification tap landed here for an order
                    // that's already finished, where a full 4-step checklist
                    // is just noise on top of the info card above.
                    if (!_isTerminal && !o.invitationPending) ...[
                      if (o.status == 'on_the_way') ...[
                        const SizedBox(height: 10),
                        ValueListenableBuilder<MasterTripTrackingState>(
                          valueListenable: _tripTracking.state,
                          builder: (context, tracking, _) => _TripTrackingCard(
                            language: lang,
                            active:
                                tracking.isActive &&
                                tracking.orderId == widget.orderId,
                            reconnecting:
                                tracking.hasNetworkError &&
                                tracking.orderId == widget.orderId,
                            busy: _busy,
                            onResume: _resumeTracking,
                            onNavigator: _showNavigatorPicker,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _Card(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (var i = 0; i < statuses.length; i++) ...[
                              if (i != 0) const SizedBox(height: 10),
                              _StatusRow(
                                status: statuses[i].copyWith(
                                  selected: i <= _selectedIndex,
                                ),
                                onTap: null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Card(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Text(
                          tr(
                            lang,
                            'Mijoz status oʻzgarishini real vaqtda koʻradi.',
                            'Клиент видит смену статуса в реальном времени.',
                            'The client sees status changes in real time.',
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            letterSpacing: -0.18,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (o.invitationPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: tr(lang, 'Rad etish', 'Отклонить', 'Decline'),
                      variant: GlassButtonVariant.secondary,
                      onPressed: _busy ? null : () => _respondInvitation(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: _busy
                          ? '…'
                          : tr(lang, 'Qabul qilish', 'Принять', 'Accept'),
                      onPressed: _busy ? null : () => _respondInvitation(true),
                    ),
                  ),
                ],
              ),
            ] else if (!_isTerminal) ...[
              const SizedBox(height: 16),
              PrimaryButton(
                label: _busy ? '…' : _buttonLabel(lang),
                onPressed: _busy ? null : _advance,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buttonLabel(AppLanguage lang) {
    return switch (_order?.status) {
      'assigned' => tr(
        lang,
        'Yo\u02bblga chiqdim',
        'Я выехал',
        'Start journey',
      ),
      'on_the_way' => tr(lang, 'Yetib keldim', 'Я приехал', 'I have arrived'),
      _ => tr(lang, 'Ishni yakunlash', 'Завершить работу', 'Finish the job'),
    };
  }

  List<_OrderStatus> _statuses(AppLanguage lang) => [
    _OrderStatus(
      label: tr(
        lang,
        'Ariza qabul qilindi',
        'Заявка принята',
        'Request accepted',
      ),
      icon: Icons.verified_rounded,
      activeColor: const Color(0xFF7C869E),
      selected: false,
    ),
    _OrderStatus(
      label: tr(lang, 'Usta yoʻlda', 'Мастер в пути', 'Master on the way'),
      icon: Icons.radio_button_checked,
      activeColor: AppColors.blue,
      selected: true,
    ),
    _OrderStatus(
      label: tr(lang, 'Manzilda', 'На месте', 'On site'),
      icon: Icons.radio_button_unchecked,
      activeColor: const Color(0xFFC9D2E3),
      selected: false,
    ),
    _OrderStatus(
      label: tr(lang, 'Bajarildi', 'Выполнено', 'Completed'),
      icon: Icons.radio_button_unchecked,
      activeColor: const Color(0xFFC9D2E3),
      selected: false,
    ),
  ];
}

class _JourneyConsentSheet extends StatelessWidget {
  const _JourneyConsentSheet({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4DCE8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            LiquidSurface(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: AppColors.blue,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr(
                language,
                'Yo\u02bblga chiqishga tayyormisiz?',
                'Готовы выехать?',
                'Ready to start the journey?',
              ),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                language,
                'Yo\u02bbl davomida FixLeo lokatsiyangizni mijozga ko\u02bbrsatadi.',
                'Во время поездки FixLeo будет показывать вашу геолокацию клиенту.',
                'FixLeo will share your location with the client during the journey.',
              ),
              style: const TextStyle(
                color: Color(0xFF71819A),
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _ConsentInfoRow(
              icon: Icons.visibility_outlined,
              text: tr(
                language,
                'Faqat shu buyurtma mijoziga ko\u02bbrinadi',
                'Геолокацию увидит только клиент этого заказа',
                'Only this order\u02bcs client can see it',
              ),
            ),
            const SizedBox(height: 12),
            _ConsentInfoRow(
              icon: Icons.stop_circle_outlined,
              text: tr(
                language,
                '“Yetib keldim” bosilganda avtomatik to\u02bbxtaydi',
                'Автоматически остановится после нажатия «Я приехал»',
                'Stops automatically when you tap “I have arrived”',
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: tr(
                language,
                'Lokatsiyani yoqish va davom etish',
                'Включить геолокацию и продолжить',
                'Enable location and continue',
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr(language, 'Hozir emas', 'Не сейчас', 'Not now')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentInfoRow extends StatelessWidget {
  const _ConsentInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LiquidSurface(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigatorSheet extends StatelessWidget {
  const _NavigatorSheet({required this.language, required this.onSelected});

  final AppLanguage language;
  final ValueChanged<NavigationApp> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4DCE8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr(
                language,
                'Navigatorni tanlang',
                'Выберите навигатор',
                'Choose a navigator',
              ),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                language,
                'Navigator ochilganda FixLeo lokatsiyani fonda yuborishda davom etadi.',
                'После открытия навигатора FixLeo продолжит передавать геолокацию в фоне.',
                'FixLeo keeps sharing your location while navigation is open.',
              ),
              style: const TextStyle(
                color: Color(0xFF71819A),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _NavigatorTile(
              icon: Icons.map_rounded,
              title: 'Google Maps',
              subtitle: tr(
                language,
                'Tavsiya etiladi',
                'Рекомендуется',
                'Recommended',
              ),
              onTap: () => onSelected(NavigationApp.googleMaps),
            ),
            const SizedBox(height: 10),
            _NavigatorTile(
              icon: Icons.navigation_rounded,
              title: 'Yandex Navigator',
              subtitle: tr(
                language,
                'Agar telefonda o\u02bbrnatilgan bo\u02bblsa',
                'Если установлен на телефоне',
                'If installed on this phone',
              ),
              onTap: () => onSelected(NavigationApp.yandexNavigator),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigatorTile extends StatelessWidget {
  const _NavigatorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: GlassContainer.lite(
        borderRadius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            LiquidSurface(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.blue, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8391A7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9DABC0)),
          ],
        ),
      ),
    );
  }
}

class _TripTrackingCard extends StatelessWidget {
  const _TripTrackingCard({
    required this.language,
    required this.active,
    required this.reconnecting,
    required this.busy,
    required this.onResume,
    required this.onNavigator,
  });

  final AppLanguage language;
  final bool active;
  final bool reconnecting;
  final bool busy;
  final VoidCallback onResume;
  final VoidCallback onNavigator;

  @override
  Widget build(BuildContext context) {
    final healthy = active && !reconnecting;
    final color = healthy ? const Color(0xFF0BA66C) : const Color(0xFFE58B20);
    final title = healthy
        ? tr(
            language,
            'Lokatsiya mijozga uzatilmoqda',
            'Геолокация передаётся клиенту',
            'Location is being shared',
          )
        : reconnecting
        ? tr(
            language,
            'Internet aloqasi kutilmoqda',
            'Ожидается подключение к интернету',
            'Waiting for an internet connection',
          )
        : tr(
            language,
            'Lokatsiya uzatilmayapti',
            'Геолокация не передаётся',
            'Location sharing is paused',
          );
    final subtitle = reconnecting
        ? tr(
            language,
            'Internet qaytganda avtomatik yangilanadi',
            'Обновится автоматически после восстановления интернета',
            'It will update when internet returns',
          )
        : active
        ? tr(
            language,
            '“Yetib keldim” bosilganda to\u02bbxtaydi',
            'Остановится после нажатия «Я приехал»',
            'Stops when you tap “I have arrived”',
          )
        : tr(
            language,
            'Mijoz harakatingizni ko\u02bbrishi uchun qayta yoqing',
            'Включите снова, чтобы клиент видел ваше движение',
            'Turn it back on so the client can follow your trip',
          );

    return GlassContainer.lite(
      tint: color,
      tintOpacityTop: 0.12,
      tintOpacityBottom: 0.06,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              LiquidSurface(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  active
                      ? reconnecting
                            ? Icons.sync_rounded
                            : Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF71819A),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onNavigator,
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: Text(
                    tr(language, 'Navigator', 'Навигатор', 'Navigator'),
                  ),
                ),
              ),
              if (!active) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onResume,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      tr(language, 'Qayta yoqish', 'Включить', 'Resume'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderStatus {
  const _OrderStatus({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final Color activeColor;
  final bool selected;

  _OrderStatus copyWith({bool? selected}) => _OrderStatus(
    label: label,
    icon: icon,
    activeColor: activeColor,
    selected: selected ?? this.selected,
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status, this.onTap});

  final _OrderStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = status.selected
        ? const Color(0xFFF1F5F9)
        : const Color(0xFFF8FAFC);
    final textColor = AppColors.navy;
    final iconColor = status.selected
        ? status.activeColor
        : const Color(0xFFC1CADB);

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer.lite(
        tint: background,
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(status.icon, size: 26, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status.label,
                style: TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (status.selected)
              LiquidSurface(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              )
            else
              LiquidSurface(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC9D2E3),
                    width: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// Gray icon + gray label row used for address / client / price.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8D96A4)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8D96A4)),
          ),
        ),
      ],
    );
  }
}
