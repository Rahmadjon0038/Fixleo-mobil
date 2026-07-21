import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
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

class _MasterCurrentRequestScreenState extends State<MasterCurrentRequestScreen> {
  final MasterMarketplaceService _market = MasterMarketplaceService();
  int? _orderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await _market.orders(status: 'current');
      if (mounted && orders.isNotEmpty) setState(() => _orderId = orders.first.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Joriy buyurtma', 'Текущая заявка', 'Current request'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card.
            _Card(
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(lang, 'Ish jarayonida', 'В работе', 'In progress'),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tr(lang, '15:10 da boshlandi', 'Начат 15:10', 'Started 15:10'),
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
            // Client card.
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
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
                              tr(lang, 'Arslan Koptleulov', 'Арслан Коптлеулов', 'Arslan Koptleulov'),
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
                      Icon(
                        Icons.location_on_outlined,
                        size: 19,
                        color: Color(0xFF8D96A4),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          tr(
                            lang,
                            'Yunusobod, Amir Temur 12, xonadon 45',
                            'Юнусабад, Амира Темура 12, кв. 45',
                            'Yunusabad, Amir Temur 12, apt. 45',
                          ),
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
            // Task card.
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
                    tr(
                      lang,
                      'Oshxonadagi smesitelni almashtirish, kartrijni almashtirish.',
                      'Замена смесителя на кухне, замена картриджа.',
                      'Replace the kitchen mixer and cartridge.',
                    ),
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
            // "Go to client now" action.
            _Card(
              onTap: () {},
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(lang, 'Mijozga hozir borish', 'Поехать к клиенту сейчас', 'Go to the client now'),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        letterSpacing: -0.18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.navy,
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(lang, 'Statusni oʻzgartirish', 'Изменить статус', 'Change status'),
              onPressed: _orderId == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MasterOrderStatusScreen(orderId: _orderId!),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded card used for every block on the screen.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
