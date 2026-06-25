import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';

/// Success screen — the master is verified and can start receiving requests.
class MasterVerifiedScreen extends StatelessWidget {
  const MasterVerifiedScreen({super.key});

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
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(44),
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 44,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Profil yaratildi!',
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
                        'Siz tasdiqlandingiz va yoningizdagi '
                        'buyurtmalarni olishingiz mumkin',
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
              label: 'Buyurtmalarga oʻtish',
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
