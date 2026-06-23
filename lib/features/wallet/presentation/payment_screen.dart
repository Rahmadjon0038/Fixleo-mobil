import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/presentation/rate_master_screen.dart';

/// A saved payment card option.
class _Card {
  const _Card({required this.number, required this.brand});

  final String number;
  final String brand;
}

/// Order payment — shows the amount due and a single-select list of saved
/// cards. Mock data for now.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _blue100 = Color(0xFFDBEAFE);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _gray = Color(0xFF8D96A4);

  static const _cards = <_Card>[
    _Card(number: 'Karta **** 4267', brand: 'Visa'),
    _Card(number: 'Karta **** 4242', brand: 'Uzcard'),
    _Card(number: 'Karta **** 4242', brand: 'Humo'),
  ];

  int _selected = 0;

  void _pay() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Toʻlov amalga oshirildi')),
      );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RateMasterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Toʻlov',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _amountCard(),
                    const SizedBox(height: 10),
                    _methodsCard(),
                    const SizedBox(height: 10),
                    _infoBanner(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _pay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'Toʻlash',
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Amount due card.
  Widget _amountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: const [
          Text(
            'Toʻlovga',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              color: _gray,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '60 000 soʻm',
            style: TextStyle(
              fontSize: 32,
              height: 38 / 32,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Smesitel almashtirish · buyurtma #1024',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: _gray,
            ),
          ),
        ],
      ),
    );
  }

  /// Payment method picker.
  Widget _methodsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Toʻlov usuli',
            style: TextStyle(
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _cards.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _cardTile(i),
          ],
        ],
      ),
    );
  }

  Widget _cardTile(int index) {
    final selected = _selected == index;
    final card = _cards[index];
    return GestureDetector(
      onTap: () => setState(() => _selected = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _slate100 : _slate50,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.number,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    card.brand,
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
            _radio(selected),
          ],
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: selected ? null : Border.all(color: _slate300, width: 2),
      ),
      child: selected
          ? const Center(
              child: Icon(Icons.circle, size: 7, color: Colors.white),
            )
          : null,
    );
  }

  /// Light-blue notice: money is only charged after work is confirmed.
  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _blue100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Pul faqat ish bajarilgani tasdiqlangandan soʻng yechiladi.',
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
