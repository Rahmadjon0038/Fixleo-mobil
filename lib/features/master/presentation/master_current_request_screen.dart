import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_order_status_screen.dart';

/// The master's active job — current status, client, address, the task
/// itself and a quick "go to client now" action, with a button to change
/// the order status at the bottom.
class MasterCurrentRequestScreen extends StatefulWidget {
  const MasterCurrentRequestScreen({super.key});

  @override
  State<MasterCurrentRequestScreen> createState() =>
      _MasterCurrentRequestScreenState();
}

class _MasterCurrentRequestScreenState
    extends State<MasterCurrentRequestScreen> {
  final MasterMarketplaceService _market = MasterMarketplaceService();
  MasterOrderDetail? _detail;
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
      final orders = await _market.orders(status: 'current');
      if (orders.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final d = await _market.orderDetail(orders.first.id);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _statusLabel(AppLanguage lang, String status) => switch (status) {
    'assigned' => tr(lang, 'Tayinlandi', 'Назначен', 'Assigned'),
    'on_the_way' => tr(lang, 'Yoʻlda', 'В пути', 'On the way'),
    'arrived' => tr(lang, 'Yetib keldi', 'На месте', 'Arrived'),
    'work_done' => tr(lang, 'Ish bajarildi', 'Работа выполнена', 'Work done'),
    _ => tr(lang, 'Ish jarayonida', 'В работе', 'In progress'),
  };

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final d = _detail;
    return BrandedScaffold(
      title: tr(lang, 'Joriy buyurtma', 'Текущая заявка', 'Current request'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : d == null
            ? Center(
                child: Text(
                  _error != null
                      ? tr(
                          lang,
                          'Yuklab boʻlmadi',
                          'Не удалось загрузить',
                          'Could not load',
                        )
                      : tr(
                          lang,
                          'Joriy buyurtma yoʻq',
                          'Нет текущей заявки',
                          'No current request',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8D96A4)),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card (real status).
                  _Card(
                    child: Row(
                      children: [
                        LiquidSurface(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel(lang, d.status),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            letterSpacing: -0.18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        const Spacer(),
                        if (d.price != null)
                          Text(
                            '${d.price} ${tr(lang, 'soʻm', 'сум', 'sum')}',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              letterSpacing: -0.16,
                              color: Color(0xFF8D96A4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Client card (real name + address).
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LiquidSurface(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 26,
                                color: Color(0xFF8D96A4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.clientName ??
                                        tr(lang, 'Mijoz', 'Клиент', 'Client'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 22 / 16,
                                      letterSpacing: -0.18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Text(
                                    tr(lang, 'Mijoz', 'Клиент', 'Client'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 20 / 14,
                                      letterSpacing: -0.16,
                                      color: Color(0xFF8D96A4),
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
                            const Icon(
                              Icons.location_on_outlined,
                              size: 19,
                              color: Color(0xFF8D96A4),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                [d.addressText, d.addressDetails]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(', '),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 20 / 14,
                                  letterSpacing: -0.16,
                                  color: Color(0xFF8D96A4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Task card (real description).
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(lang, 'Vazifa', 'Задача', 'Task'),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            letterSpacing: -0.18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          d.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            letterSpacing: -0.16,
                            color: Color(0xFF8D96A4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: tr(
                      lang,
                      'Statusni oʻzgartirish',
                      'Изменить статус',
                      'Change status',
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MasterOrderStatusScreen(orderId: d.id),
                        ),
                      );
                      if (mounted) _load();
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/// Frosted glass card used for every block on the screen.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
