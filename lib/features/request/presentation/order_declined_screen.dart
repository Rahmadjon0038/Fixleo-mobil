import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/request/presentation/masters_responses_screen.dart';

/// "Отклонено." — shown when the chosen master declines the request. The
/// client is sent back to the other responses to pick a new master
/// (Figma node 997:9884).
class OrderDeclinedScreen extends StatelessWidget {
  const OrderDeclinedScreen({
    super.key,
    this.orderId,
    this.canChooseAnotherMaster = true,
    this.responsesBuilder,
  });

  final int? orderId;
  final bool canChooseAnotherMaster;
  final WidgetBuilder? responsesBuilder;

  static const _red100 = Color(0xFFFEE2E2);
  static const _red400 = Color(0xFFF87171);
  static const _gray = Color(0xFF8D96A4);

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      showBack: true,
      onBack: () => Navigator.of(context).popUntil((route) => route.isFirst),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            const Spacer(),
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _red100,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: _red400,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(lang, 'Rad etildi.', 'Отклонено.', 'Declined.'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canChooseAnotherMaster
                        ? tr(
                            lang,
                            'Usta arizangizni rad etdi — boshqa javoblarga oʻtib, '
                                'yangi usta topishingiz mumkin.',
                            'Мастер отклонил вашу заявку, вы можете перейти к '
                                'другим откликам и найти нового мастера.',
                            'The master declined your request — you can go to the '
                                'other responses and find a new master.',
                          )
                        : tr(
                            lang,
                            'Usta buyurtmani bekor qildi. Belgilangan vaqt o‘tib ketgani '
                                'uchun ushbu buyurtma qayta ochilmadi.',
                            'Мастер отменил заказ. Из-за истёкшего времени заказ '
                                'не удалось открыть повторно.',
                            'The master cancelled the order. It could not be reopened '
                                'because its scheduled time had passed.',
                          ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: canChooseAnotherMaster
                  ? tr(
                      lang,
                      'Javoblarga oʻtish',
                      'Перейти к откликам',
                      'Go to responses',
                    )
                  : tr(
                      lang,
                      'Bosh sahifaga qaytish',
                      'Вернуться на главную',
                      'Return home',
                    ),
              onPressed: () {
                if (canChooseAnotherMaster && orderId != null) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          responsesBuilder ??
                          (_) => MastersResponsesScreen(orderId: orderId!),
                    ),
                  );
                } else {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
