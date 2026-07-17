import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_current_request_screen.dart';

/// Confirmation that the master's offer was sent, then auto-opens the
/// current request screen after a short pause.
class MasterOfferSentScreen extends StatefulWidget {
  const MasterOfferSentScreen({super.key});

  @override
  State<MasterOfferSentScreen> createState() => _MasterOfferSentScreenState();
}

class _MasterOfferSentScreenState extends State<MasterOfferSentScreen> {
  static const _autoNavigateDelay = Duration(milliseconds: 1400);
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_autoNavigateDelay, _goToCurrentRequest);
  }

  void _goToCurrentRequest() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MasterCurrentRequestScreen(),
      ),
    );
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
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
                        tr(lang, 'Javob yuborildi', 'Ответ отправлен', 'Response sent'),
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
              label: tr(lang, 'Buyurtmalar lentasiga', 'В ленту заказов', 'To requests feed'),
              onPressed: _goToCurrentRequest,
            ),
          ],
        ),
      ),
    );
  }
}
