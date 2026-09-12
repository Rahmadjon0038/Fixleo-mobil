import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/order_status.dart';
import 'package:fixleo/features/request/presentation/order_done_screen.dart';

/// The state of a single timeline step.
enum _StepState { done, current, pending }

/// One step in the order timeline.
class _Step {
  const _Step({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final _StepState state;
}

/// Order status — a vertical timeline tracking the order from acceptance to
/// completion, driven by the live `GET /clients/me/orders/:id` status +
/// capabilities. The bottom button reflects the next available client action.
class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({
    super.key,
    required this.orderId,
    this.orderService,
  });

  final int orderId;
  final OrderService? orderService;

  static const _slate200 = Color(0xFFE2E8F0);
  static const _text = Color(0xFF23232E);
  static const _muted = Color(0xFF9494A3);

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  static const _slate200 = OrderStatusScreen._slate200;
  static const _text = OrderStatusScreen._text;
  static const _muted = OrderStatusScreen._muted;

  late final OrderService _service = widget.orderService ?? OrderService();
  OrderDetail? _order;
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
      final o = await _service.detail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = o;
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

  /// True once a master is actually assigned — the 4-step timeline (assigned →
  /// … → work_done) only begins then. While the order is still `searching`
  /// (or expired/cancelled), none of these steps has started.
  bool get _started => const {
    'assigned',
    'on_the_way',
    'arrived',
    'work_done',
    'completed',
    'disputed',
  }.contains(_order?.status);

  _StepState _stepState(int i) {
    // Don't light up "Мастер назначен" as current while still searching — no
    // master is assigned yet, so every step is pending.
    if (!_started) return _StepState.pending;

    if (const {'completed', 'disputed'}.contains(_order?.status)) {
      return _StepState.done;
    }

    final current = switch (_order?.status) {
      'assigned' => 0,
      'on_the_way' => 1,
      'arrived' => 2,
      'work_done' => 3,
      _ => -1,
    };
    if (i < current) return _StepState.done;
    if (i == current) return _StepState.current;
    return _StepState.pending;
  }

  List<_Step> _steps(AppLanguage lang) {
    const pending = _StepState.pending;
    String sub(_StepState s) => s == pending
        ? tr(lang, 'Kutilmoqda', 'Ожидается', 'Pending')
        : s == _StepState.current
        ? tr(lang, 'Hozir', 'Сейчас', 'Now')
        : tr(lang, 'Bajarildi', 'Готово', 'Done');
    final titles = [
      tr(lang, 'Usta tayinlandi', 'Мастер назначен', 'Master assigned'),
      tr(lang, 'Usta yoʻlda', 'Мастер в пути', 'Master on the way'),
      tr(lang, 'Usta yetib keldi', 'Мастер прибыл', 'Master arrived'),
      tr(lang, 'Ish bajarildi', 'Работа выполнена', 'Work completed'),
    ];
    return [
      for (int i = 0; i < 4; i++)
        _Step(
          title: titles[i],
          subtitle: sub(_stepState(i)),
          state: _stepState(i),
        ),
    ];
  }

  Future<void> _reviewCompletion() async {
    setState(() => _busy = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OrderDoneScreen(orderId: widget.orderId, orderService: _service),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Buyurtma holati', 'Статус заказа', 'Order status'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: _muted)),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _timelineCard(_steps(lang)),
                          const SizedBox(height: 10),
                          _noticeBanner(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _actionButton(lang),
                ],
              ),
      ),
    );
  }

  Widget _actionButton(AppLanguage lang) {
    final caps = _order?.capabilities;
    final canConfirm = caps?.canConfirm == true;
    final status = _order?.status ?? '';
    final shouldReturnHome =
        isCancelledOrderStatus(status) || status == 'expired';
    final label = shouldReturnHome
        ? tr(
            lang,
            'Bosh sahifaga qaytish',
            'Вернуться на главную',
            'Return home',
          )
        : canConfirm
        ? tr(
            lang,
            'Bajarilganini tasdiqlash',
            'Подтвердить выполнение',
            'Confirm completion',
          )
        : tr(
            lang,
            'Holat kuzatilmoqda',
            'Статус отслеживается',
            'Tracking status',
          );
    final onPressed = shouldReturnHome
        ? () => Navigator.of(context).popUntil((route) => route.isFirst)
        : (canConfirm && !_busy)
        ? _reviewCompletion
        : null;
    final disabled = onPressed == null;
    // Custom GlassContainer button (mirrors GlassButton's primary variant)
    // instead of GlassButton itself, since this action needs a busy-spinner
    // swap that GlassButton's fixed label/icon slot doesn't support.
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ExcludeSemantics(
            child: GlassContainer(
              tint: disabled
                  ? AppColors.blue.withValues(alpha: 0.5)
                  : AppColors.blue,
              tintOpacityTop: 0.90,
              tintOpacityBottom: 0.74,
              borderOpacity: 0.5,
              borderRadius: 26,
              height: 52,
              shadow: !disabled,
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
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(
                          alpha: disabled ? 0.7 : 1,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timelineCard(List<_Step> steps) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++)
            _stepRow(steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }

  /// One timeline row: status marker + connector on the left, text on the right.
  Widget _stepRow(_Step step, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _marker(step.state),
            if (!isLast)
              LiquidSurface(
                width: 3,
                height: 30,
                color: step.state == _StepState.done
                    ? AppColors.blue
                    : _slate200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  fontWeight: FontWeight.w700,
                  color: step.state == _StepState.pending ? _muted : _text,
                ),
              ),
              Text(
                step.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The 26px circular marker for a step, varying by [state].
  Widget _marker(_StepState state) {
    switch (state) {
      case _StepState.done:
        return LiquidSurface(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return LiquidSurface(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _slate200,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: LiquidSurface(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _StepState.pending:
        return LiquidSurface(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _slate200,
            borderRadius: BorderRadius.circular(13),
          ),
        );
    }
  }

  Widget _noticeBanner() {
    final language = LocaleController.language.value;
    final status = _order?.status ?? '';
    final isTerminal = isTerminalOrderStatus(status);
    return GlassContainer(
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
      tint: AppColors.blue,
      tintOpacityTop: 0.20,
      tintOpacityBottom: 0.12,
      borderOpacity: 0.35,
      child: Text(
        isTerminal
            ? orderStatusLabel(language, status)
            : tr(
                language,
                'Holat oʻzgarganda bildirishnoma yuboramiz',
                'Мы отправим уведомление при изменении статуса',
                'We will notify you when the status changes',
              ),
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
