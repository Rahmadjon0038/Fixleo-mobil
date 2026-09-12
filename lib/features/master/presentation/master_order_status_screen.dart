import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
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

class _MasterOrderStatusScreenState extends State<MasterOrderStatusScreen> {
  static const _terminalStatuses = {
    'completed',
    'disputed',
    'cancelled_by_client',
    'cancelled_by_master',
    'expired',
  };

  final MasterMarketplaceService _market = MasterMarketplaceService();
  MasterOrderDetail? _order;
  bool _loading = true;
  bool _busy = false;

  /// A finished/cancelled/expired order has nothing left to "advance" —
  /// notification taps (payment received, order completed, ...) land here
  /// for orders in exactly this state, so the advance button needs to stay
  /// hidden instead of offering to re-run the completion flow.
  bool get _isTerminal => _terminalStatuses.contains(_order?.status);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _market.orderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    setState(() => _busy = true);
    try {
      if (o.status == 'assigned') {
        final u = await _market.setStatus(widget.orderId, 'on_the_way');
        if (mounted) {
          setState(() {
            _order = u;
            _busy = false;
          });
        }
      } else if (o.status == 'on_the_way') {
        final u = await _market.setStatus(widget.orderId, 'arrived');
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
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
              : Text(
                  tr(
                    lang,
                    'Buyurtmani yuklab boʻlmadi',
                    'Не удалось загрузить заказ',
                    'Could not load the order',
                  ),
                  style: const TextStyle(color: Color(0xFF8D96A4)),
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
                    // The step-by-step tracker only means something for a
                    // job still in progress — a "payment received"/"order
                    // completed" notification tap landed here for an order
                    // that's already finished, where a full 4-step checklist
                    // is just noise on top of the info card above.
                    if (!_isTerminal) ...[
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
            if (!_isTerminal) ...[
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
    final statuses = _statuses(lang);
    if (_selectedIndex >= statuses.length - 1) {
      return tr(lang, 'Ishni yakunlash', 'Завершить работу', 'Finish the job');
    }
    return tr(
      lang,
      'Statusni “${statuses[_selectedIndex + 1].label}” deb belgilash',
      'Отметить статус “${statuses[_selectedIndex + 1].label}”',
      'Mark status as "${statuses[_selectedIndex + 1].label}"',
    );
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
