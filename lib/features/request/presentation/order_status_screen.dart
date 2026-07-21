import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/order_done_screen.dart';

/// The state of a single timeline step.
enum _StepState { done, current, pending }

/// One step in the order timeline.
class _Step {
  const _Step({required this.title, required this.subtitle, required this.state});

  final String title;
  final String subtitle;
  final _StepState state;
}

/// Order status — a vertical timeline tracking the order from acceptance to
/// completion, driven by the live `GET /clients/me/orders/:id` status +
/// capabilities. The bottom button reflects the next available client action.
class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final int orderId;

  static const _blue100 = Color(0xFFDBEAFE);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _text = Color(0xFF23232E);
  static const _muted = Color(0xFF9494A3);

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  static const _blue100 = OrderStatusScreen._blue100;
  static const _slate200 = OrderStatusScreen._slate200;
  static const _text = OrderStatusScreen._text;
  static const _muted = OrderStatusScreen._muted;

  final OrderService _service = OrderService();
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

  int get _doneSteps => switch (_order?.status) {
        'assigned' => 1,
        'on_the_way' => 2,
        'arrived' => 3,
        'work_done' || 'completed' || 'disputed' => 4,
        _ => 0,
      };

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
    final d = _doneSteps;
    if (d >= i + 1) return _StepState.done;
    if (d == i) return _StepState.current;
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
        _Step(title: titles[i], subtitle: sub(_stepState(i)), state: _stepState(i)),
    ];
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await _service.confirmCompletion(widget.orderId);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDoneScreen(orderId: widget.orderId)),
      );
      if (mounted) _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
                ? Center(child: Text(_error!, style: const TextStyle(color: _muted)))
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
    final label = canConfirm
        ? tr(lang, 'Bajarilganini tasdiqlash', 'Подтвердить выполнение', 'Confirm completion')
        : tr(lang, 'Holat kuzatilmoqda', 'Статус отслеживается', 'Tracking status');
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: (canConfirm && !_busy) ? _confirm : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: _slate200,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
        child: _busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _timelineCard(List<_Step> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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
              Container(
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
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _slate200,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Container(
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
        return Container(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        tr(
          LocaleController.language.value,
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
