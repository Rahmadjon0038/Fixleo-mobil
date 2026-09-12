import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';

/// Result screen shown after the master requests a withdrawal.
class MasterWithdrawResultScreen extends StatelessWidget {
  const MasterWithdrawResultScreen({
    super.key,
    required this.success,
    this.amount = '50 000 soʻm',
  });

  final bool success;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final iconBg = success ? const Color(0xFFEFF6FF) : const Color(0xFFFEE2E2);
    final iconColor = success ? AppColors.blue : const Color(0xFFEF4444);
    final title = success
        ? tr(
            lang,
            'Oʻtkazma muvaffaqiyatli',
            'Перевод прошел',
            'Transfer successful',
          )
        : tr(
            lang,
            'Oʻtkazma muvaffaqiyatsiz',
            'Перевод не прошел',
            'Transfer failed',
          );
    final subtitle = success
        ? tr(
            lang,
            '$amount - tasdiqlanguncha ushlab turiladi\nChek “Hamyon” bo‘limiga yuborildi',
            '$amount - холд до подтверждения\nЧек отправлен в раздел “Кошелек”',
            '$amount - held until confirmation\nReceipt sent to “Wallet”',
          )
        : tr(
            lang,
            'Mablagʻ yetarli emas yoki bank\namaliyotni rad etdi. Pul yechilmadi.',
            'Недостаточно средств или банк\nотклонил операцию. Деньги\nне списались.',
            'Insufficient funds or the bank\nrejected the operation. No money\nwas withdrawn.',
          );

    return BrandedScaffold(
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            const Spacer(),
            GlassContainer(
              width: double.infinity,
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidSurface(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      success ? Icons.check : Icons.close,
                      size: 34,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      letterSpacing: -0.15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF23232E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      color: Color(0xFF6B6B7A),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(lang, 'Bosh sahifaga', 'На главную', 'To home'),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MasterHomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
