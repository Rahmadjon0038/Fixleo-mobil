import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// Confirmation that the master's offer was sent. An offer is not an assigned
/// job yet, so this screen must never open the work-status flow automatically.
class MasterOfferSentScreen extends StatelessWidget {
  const MasterOfferSentScreen({super.key});

  void _goToFeed(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: GlassCard(
                  radius: 30,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiquidSurface(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 36,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr(
                          lang,
                          'Javob yuborildi',
                          'Ответ отправлен',
                          'Response sent',
                        ),
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
                        tr(
                          lang,
                          'Agar mijoz sizni tanlasa — bildirishnoma keladi va chat ochiladi.',
                          'Если клиент выберет вас — придет уведомление и откроется чат.',
                          'If the client chooses you, a notification will arrive and the chat will open.',
                        ),
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
              ),
            ),
            PrimaryButton(
              label: tr(
                lang,
                'Buyurtmalar lentasiga',
                'В ленту заказов',
                'To requests feed',
              ),
              onPressed: () => _goToFeed(context),
            ),
          ],
        ),
      ),
    );
  }
}
