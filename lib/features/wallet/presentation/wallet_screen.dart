import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/wallet/presentation/add_card_screen.dart';
import 'package:fixleo/features/wallet/presentation/payment_screen.dart';

/// A single wallet transaction.
class _Txn {
  const _Txn({
    required this.titleUz,
    required this.titleRu,
    required this.titleEn,
    required this.dateUz,
    required this.dateRu,
    required this.dateEn,
    required this.amount,
  });

  final String titleUz;
  final String titleRu;
  final String titleEn;
  final String dateUz;
  final String dateRu;
  final String dateEn;
  final String amount;

  String title(AppLanguage lang) => tr(lang, titleUz, titleRu, titleEn);
  String date(AppLanguage lang) => tr(lang, dateUz, dateRu, dateEn);
}

/// Wallet — card balance, top-up/history actions and a transactions list.
/// Mock data for now.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const _navy900 = Color(0xFF0F172A);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _gray = Color(0xFF8D96A4);

  static const _txns = <_Txn>[
    _Txn(
      titleUz: 'Toʻlov - Santexnika',
      titleRu: 'Оплата - Сантехника',
      titleEn: 'Payment - Plumbing',
      dateUz: 'Bugun, 14:30',
      dateRu: 'Сегодня, 14:30',
      dateEn: 'Today, 14:30',
      amount: '-60 000',
    ),
    _Txn(
      titleUz: 'Toʻldirish - Rahmat Pay',
      titleRu: 'Пополнение - Rahmat Pay',
      titleEn: 'Top-up - Rahmat Pay',
      dateUz: 'Bugun, 14:30',
      dateRu: 'Сегодня, 14:30',
      dateEn: 'Today, 14:30',
      amount: '+50 000',
    ),
    _Txn(
      titleUz: 'Toʻlov - Santexnika',
      titleRu: 'Оплата - Сантехника',
      titleEn: 'Payment - Plumbing',
      dateUz: 'Bugun, 14:30',
      dateRu: 'Сегодня, 14:30',
      dateEn: 'Today, 14:30',
      amount: '-60 000',
    ),
    _Txn(
      titleUz: 'Toʻldirish - Rahmat Pay',
      titleRu: 'Пополнение - Rahmat Pay',
      titleEn: 'Top-up - Rahmat Pay',
      dateUz: 'Bugun, 14:30',
      dateRu: 'Сегодня, 14:30',
      dateEn: 'Today, 14:30',
      amount: '+50 000',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Hamyon', 'Кошелек', 'Wallet'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _balanceCard(context),
              const SizedBox(height: 10),
              _addCard(context),
              const SizedBox(height: 10),
              _operationsCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark balance card with top-up / history actions.
  Widget _balanceCard(BuildContext context) {
    final lang = LocaleController.language.value;
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
            children: [
              Text(
                tr(lang, 'Karta balansi', 'Баланс карты', 'Card balance'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: Color(0xFFEDEBFC),
                ),
              ),
              const Spacer(),
              const Icon(
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
                  tr(lang, 'Toʻldirish', 'Пополнить', 'Top up'),
                  background: Colors.white,
                  foreground: AppColors.navy,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          title: tr(lang, 'Toʻldirish', 'Пополнение', 'Top up'),
                          amountLabel: tr(lang, 'Balansga', 'К пополнению', 'To balance'),
                          amount: tr(lang, '60 000 soʻm', '60 000 сум', '60 000 sum'),
                          subtitle: tr(lang, 'Balansni toʻldirish', 'Пополнение баланса', 'Balance top-up'),
                          primaryLabel: tr(lang, 'Toʻldirish', 'Пополнить', 'Top up'),
                          onSuccess: () => Navigator.of(context).pop(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _balanceButton(
                  tr(lang, 'Tarix', 'История', 'History'),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  /// "Add card" outlined pill.
  Widget _addCard(BuildContext context) {
    final lang = LocaleController.language.value;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddCardScreen()),
          );
        },
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 20, color: _gray),
              const SizedBox(width: 8),
              Text(
                tr(lang, 'Karta qoʻshish', 'Добавить карту', 'Add card'),
                style: const TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  letterSpacing: -0.18,
                  fontWeight: FontWeight.w500,
                  color: _gray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Operations list.
  Widget _operationsCard() {
    final lang = LocaleController.language.value;
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
          Text(
            tr(lang, 'Amaliyotlar', 'Операции', 'Operations'),
            style: const TextStyle(
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _txns.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _txnTile(_txns[i], lang),
          ],
        ],
      ),
    );
  }

  Widget _txnTile(_Txn txn, AppLanguage lang) {
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
                  txn.title(lang),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  txn.date(lang),
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
