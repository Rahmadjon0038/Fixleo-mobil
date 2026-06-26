import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// The master's active job — current status, client, address, the task
/// itself and a quick "go to client now" action, with a button to change
/// the order status at the bottom.
class MasterCurrentRequestScreen extends StatelessWidget {
  const MasterCurrentRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Joriy buyurtma',
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
                  const Text(
                    'Ishda',
                    style: TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Boshlandi 15:10',
                    style: TextStyle(
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
                          children: const [
                            Text(
                              'Arslan Koptleulov',
                              style: TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                letterSpacing: -0.18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              'Mijoz',
                              style: TextStyle(
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
                    children: const [
                      Icon(
                        Icons.location_on_outlined,
                        size: 19,
                        color: Color(0xFF8D96A4),
                      ),
                      SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          'Yunusobod, Amir Temur 12, 45-xonadon',
                          style: TextStyle(
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
                children: const [
                  Text(
                    'Vazifa',
                    style: TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    'Oshxonadagi smesitelni almashtirish, kartrijni almashtirish.',
                    style: TextStyle(
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
                children: const [
                  Expanded(
                    child: Text(
                      'Hozir mijoznikiga borish',
                      style: TextStyle(
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
              label: 'Statusni oʻzgartirish',
              onPressed: () {},
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
