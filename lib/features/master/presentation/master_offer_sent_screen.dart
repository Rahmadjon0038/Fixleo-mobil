import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// Confirmation that the master's offer was sent. Returning takes them back
/// to the requests feed.
class MasterOfferSentScreen extends StatelessWidget {
  const MasterOfferSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      const Text(
                        'Javob yuborildi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          height: 30 / 24,
                          letterSpacing: -0.15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF23232E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Agar mijoz sizni tanlasa — bildirishnoma keladi '
                        'va chat ochiladi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
              label: 'Buyurtmalar lentasiga',
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
