import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// A card the master can withdraw funds to.
class _Card {
  const _Card({required this.number, required this.system});

  final String number;
  final String system;
}

/// "Withdraw funds" screen — available balance, amount input, a card picker and
/// a fee notice, with a withdraw button. Opens from the wallet.
class MasterWithdrawScreen extends StatefulWidget {
  const MasterWithdrawScreen({super.key});

  @override
  State<MasterWithdrawScreen> createState() => _MasterWithdrawScreenState();
}

class _MasterWithdrawScreenState extends State<MasterWithdrawScreen> {
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _gray = Color(0xFF8D96A4);

  static const _cards = <_Card>[
    _Card(number: 'Karta **** 4267', system: 'Visa'),
    _Card(number: 'Karta **** 4242', system: 'Uzcard'),
    _Card(number: 'Karta **** 4242', system: 'Humo'),
  ];

  final _amount = TextEditingController(text: '50 000');
  int _selectedCard = 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Mablagʻ yechish',
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _balanceCard(),
                const SizedBox(height: 10),
                _amountCard(),
                const SizedBox(height: 10),
                _cardsCard(),
                const SizedBox(height: 10),
                _feeNotice(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: PrimaryButton(
              label: 'Yechish 125 000',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  /// Dark "available to withdraw" card.
  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Yechish mumkin',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '125 000 soʻm',
            style: TextStyle(
              fontSize: 24,
              height: 30 / 24,
              letterSpacing: -0.15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Amount input card.
  Widget _amountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summa',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23232E),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    ],
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'soʻm',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: _gray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Where to withdraw" card with selectable cards.
  Widget _cardsCard() {
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
            'Qayerga yechish',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _cards.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _cardOption(i),
          ],
        ],
      ),
    );
  }

  Widget _cardOption(int index) {
    final card = _cards[index];
    final selected = _selectedCard == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCard = index),
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
                    card.system,
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
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }

  /// Orange fee-notice banner.
  Widget _feeNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.error_outline, size: 20, color: Color(0xFFFB923C)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '1 kun ichida yechish — 1.5% bilan, lekin 7 kun ichida '
              'yechsangiz xizmat foizsiz boʻladi.',
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.16,
                color: Color(0xFFFB923C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round radio dot — blue filled when selected, gray ring when not.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.blue : const Color(0xFFCBD5E1),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
