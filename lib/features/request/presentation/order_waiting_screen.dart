import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/home/presentation/home_screen.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

/// "Ожидание…" — shown right after the client confirms a master. The
/// confirmation is sent to the master; once they respond, chat and status
/// tracking open (Figma node 997:9812).
///
/// Mock behaviour for now: after a short delay the master "accepts" and the
/// screen moves on to live order tracking. Real realtime events will replace
/// the timer once the backend flow is wired.
class OrderWaitingScreen extends StatefulWidget {
  const OrderWaitingScreen({super.key, this.orderId});

  /// The just-created order; when set, tracking opens for it.
  final int? orderId;

  @override
  State<OrderWaitingScreen> createState() => _OrderWaitingScreenState();
}

class _OrderWaitingScreenState extends State<OrderWaitingScreen> {
  static const _blue100 = Color(0xFFDBEAFE);
  static const _gray = Color(0xFF8D96A4);

  Timer? _mockAccept;

  @override
  void initState() {
    super.initState();
    // Once an order exists, move on to live tracking (which polls real status).
    final id = widget.orderId;
    if (id != null) {
      _mockAccept = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: id)),
        );
      });
    }
  }

  @override
  void dispose() {
    _mockAccept?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: _blue100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history,
                      size: 30,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(lang, 'Kutilmoqda…', 'Ожидание…', 'Waiting…'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      lang,
                      'Tasdiqlash ustaga yuborildi. U javob bergach, chat '
                          'va status kuzatuvi ochiladi.',
                      'Подтверждение отправлено мастеру. После его ответа '
                          'откроются чат и отслеживание статуса.',
                      'The confirmation was sent to the master. Once they '
                          'respond, chat and status tracking will open.',
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
              label: tr(lang, 'Bosh sahifaga', 'На главную', 'To home'),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
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
