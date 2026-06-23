import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';

/// A single wallet transaction.
class _Txn {
  const _Txn({required this.title, required this.date, required this.amount});

  final String title;
  final String date;
  final String amount;
}

/// Wallet — card balance, top-up/history actions and a transactions list.
/// Mock data for now.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const _navy900 = Color(0xFF0F172A);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _gray = Color(0xFF8D96A4);

  static const _txns = <_Txn>[
    _Txn(title: 'Toʻlov - Santexnika', date: 'Bugun, 14:30', amount: '-60 000'),
    _Txn(
      title: 'Toʻldirish - Rahmat Pay',
      date: 'Bugun, 14:30',
      amount: '+50 000',
    ),
    _Txn(title: 'Toʻlov - Santexnika', date: 'Bugun, 14:30', amount: '-60 000'),
    _Txn(
      title: 'Toʻldirish - Rahmat Pay',
      date: 'Bugun, 14:30',
      amount: '+50 000',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Hamyon',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _balanceCard(),
              const SizedBox(height: 10),
              _addCard(),
              const SizedBox(height: 10),
              _operationsCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark balance card with top-up / history actions.
  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _navy900,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Karta balansi',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: Color(0xFFEDEBFC),
                ),
              ),
              Spacer(),
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '125 000 soʻm',
            style: TextStyle(
              fontSize: 32,
              height: 38 / 32,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _balanceButton(
                  'Toʻldirish',
                  background: Colors.white,
                  foreground: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _balanceButton(
                  'Tarix',
                  background: Colors.white.withValues(alpha: 0.18),
                  foreground: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceButton(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }

  /// "Add card" outlined pill.
  Widget _addCard() {
    return Container(
      width: double.infinity,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.add, size: 20, color: _gray),
          SizedBox(width: 8),
          Text(
            'Karta qoʻshish',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w500,
              color: _gray,
            ),
          ),
        ],
      ),
    );
  }

  /// Operations list.
  Widget _operationsCard() {
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
            'Amaliyotlar',
            style: TextStyle(
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _txns.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _txnTile(_txns[i]),
          ],
        ],
      ),
    );
  }

  Widget _txnTile(_Txn txn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.title,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  txn.date,
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
          const SizedBox(width: 8),
          Text(
            txn.amount,
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
