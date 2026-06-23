import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/order_complaint_screen.dart';
import 'package:fixleo/features/wallet/presentation/payment_screen.dart';

/// "Buyurtma bajarildimi?" — the master marked the work done; the user confirms
/// completion or reports a problem. Mock data for now.
class OrderDoneScreen extends StatelessWidget {
  const OrderDoneScreen({super.key});

  static const _slate100 = Color(0xFFF1F5F9);
  static const _gray = Color(0xFF8D96A4);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Buyurtma bajarildimi?',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _statusCard(),
                    const SizedBox(height: 10),
                    _detailsCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _actions(context),
          ],
        ),
      ),
    );
  }

  /// Centered badge + headline confirming the master's report.
  Widget _statusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.verified, size: 42, color: AppColors.blue),
          ),
          const SizedBox(height: 10),
          const SizedBox(
            width: 196,
            child: Text(
              'Usta ishni bajarilgan deb belgiladi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                letterSpacing: -0.18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Order summary rows.
  Widget _detailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: const [
          _DetailRow(label: 'Xizmat', value: 'Smesitel almashtirish'),
          SizedBox(height: 8),
          _DetailRow(label: 'Vaqt', value: 'Bugun, 12:00–15:00'),
          SizedBox(height: 8),
          _DetailRow(label: 'Usta taklifi', value: '50 000 soʻm'),
        ],
      ),
    );
  }

  /// Primary confirm button + a muted "report a problem" link.
  Widget _actions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaymentScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: const Text(
              'Bajarilganini tasdiqlash',
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                letterSpacing: -0.18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderComplaintScreen()),
            );
          },
          child: const Text(
            'Buyurtmada muammo bor',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              color: _gray,
            ),
          ),
        ),
      ],
    );
  }
}

/// A "label … value" row of the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.16,
            color: OrderDoneScreen._gray,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
