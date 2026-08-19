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
  final MasterMarketplaceService _market = MasterMarketplaceService();
  MasterOrderDetail? _order;
  bool _loading = true;
  bool _busy = false;

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
    if (o == null || _busy) return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final statuses = _statuses(lang);
    if (_loading) {
      return BrandedScaffold(
        title: tr(lang, 'Buyurtma holati', 'Статус заказа', 'Order status'),
        showBack: true,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return BrandedScaffold(
      title: tr(lang, 'Buyurtma holati', 'Статус заказа', 'Order status'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            const Spacer(),
            PrimaryButton(
              label: _busy ? '…' : _buttonLabel(lang),
              onPressed: _busy ? null : _advance,
            ),
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
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              )
            else
              Container(
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
