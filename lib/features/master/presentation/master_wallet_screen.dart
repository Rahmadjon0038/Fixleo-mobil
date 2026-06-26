import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/features/master/presentation/master_withdraw_screen.dart';

/// A single wallet transaction in the master's operations list.
class _Txn {
  const _Txn({required this.title, required this.date, required this.amount});

  final String title;
  final String date;
  final String amount;
}

/// Master's wallet — available balance with a withdraw action, quick stats
/// (orders / rating / earned) and a list of recent operations. Shown under the
/// "Hamyon" tab. Mock data only.
class MasterWalletScreen extends StatelessWidget {
  const MasterWalletScreen({super.key});

  static const _navy900 = Color(0xFF0F172A);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _gray = Color(0xFF8D96A4);

  static const _txns = <_Txn>[
    _Txn(title: 'Kartaga toʻlov', date: 'Bugun, 14:30', amount: '+50 000'),
    _Txn(title: 'Mablagʻ yechish', date: 'Bugun, 14:30', amount: '-60 000'),
    _Txn(title: 'Kartaga toʻlov', date: 'Bugun, 14:30', amount: '+50 000'),
    _Txn(title: 'Mablagʻ yechish', date: 'Bugun, 14:30', amount: '-60 000'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _balanceCard(context),
        const SizedBox(height: 10),
        _statsRow(),
        const SizedBox(height: 10),
        _operationsCard(),
      ],
    );
  }

  /// Dark balance card with the withdraw button.
  Widget _balanceCard(BuildContext context) {
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
                'Mavjud',
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
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MasterWithdrawScreen(),
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Mablagʻni yechish',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Three quick-stat cards: orders, rating, earned this month.
  Widget _statsRow() {
    return Row(
      children: const [
        Expanded(child: _StatCard(value: '48', label: 'buyurtma')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(value: '4.9', label: 'reyting')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(value: '850 000', label: 'Mayda ishlangan')),
      ],
    );
  }

  /// Operations list card.
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
            'Operatsiyalar',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
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

/// One white quick-stat card (bold value + small gray label).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8D96A4),
            ),
          ),
        ],
      ),
    );
  }
}
