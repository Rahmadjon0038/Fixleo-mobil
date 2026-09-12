import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_withdraw_screen.dart';

/// Master's wallet — available balance with a withdraw action, quick stats
/// (orders / rating / earned) and a list of recent operations. Shown under the
/// "Hamyon" tab. Mock data only.
class MasterWalletScreen extends StatefulWidget {
  const MasterWalletScreen({super.key});

  static const _gray = Color(0xFF8D96A4);
  static const _navy900 = Color(0xFF0F172A);

  @override
  State<MasterWalletScreen> createState() => _MasterWalletScreenState();
}

class _MasterWalletScreenState extends State<MasterWalletScreen> {
  static const _gray = MasterWalletScreen._gray;
  static const _navy900 = MasterWalletScreen._navy900;

  final MasterMarketplaceService _market = MasterMarketplaceService();
  MasterWallet? _wallet;
  List<WalletTx> _txns = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _market.wallet(),
        _market.transactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as MasterWallet;
        _txns = results[1] as List<WalletTx>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _money(int v) {
    final neg = v < 0;
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}${buf.toString()}';
  }

  String _txLabel(String type, AppLanguage lang) => switch (type) {
    'order_income' => tr(
      lang,
      'Buyurtma toʻlovi',
      'Оплата за заказ',
      'Order payment',
    ),
    'withdrawal' => tr(lang, 'Mablagʻ yechish', 'Вывод средств', 'Withdrawal'),
    'withdrawal_fee' => tr(
      lang,
      'Yechish komissiyasi',
      'Комиссия за вывод',
      'Withdrawal fee',
    ),
    'withdrawal_refund' => tr(
      lang,
      'Yechish qaytarildi',
      'Возврат вывода',
      'Withdrawal refund',
    ),
    'refund_out' => tr(
      lang,
      'Mijozga qaytarish',
      'Возврат клиенту',
      'Refund to client',
    ),
    _ => tr(lang, 'Operatsiya', 'Операция', 'Operation'),
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _balanceCard(context),
          const SizedBox(height: 10),
          _statsRow(),
          const SizedBox(height: 10),
          _operationsCard(),
        ],
      ),
    );
  }

  /// Dark balance card with the withdraw button.
  Widget _balanceCard(BuildContext context) {
    final lang = LocaleController.language.value;
    return LiquidSurface(
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
                tr(lang, 'Mavjud', 'Доступно', 'Available'),
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
          Text(
            '${_money(_wallet?.balance ?? 0)} ${tr(lang, 'soʻm', 'сум', 'sum')}',
            style: const TextStyle(
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
              MaterialPageRoute(builder: (_) => const MasterWithdrawScreen()),
            ),
            child: LiquidSurface(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tr(
                  lang,
                  'Mablagʻni yechish',
                  'Вывести средства',
                  'Withdraw funds',
                ),
                style: const TextStyle(
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
    final lang = LocaleController.language.value;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${_wallet?.completedOrders ?? 0}',
            label: tr(lang, 'buyurtma', 'заказа', 'orders'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: _wallet?.ratingAvg?.toStringAsFixed(1) ?? '—',
            label: tr(lang, 'reyting', 'рейтинг', 'rating'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: _money(_wallet?.monthEarned ?? 0),
            label: _earnedLabel(lang),
          ),
        ),
      ],
    );
  }

  /// "Заработано в Мае"-style label for the current month (FINAL).
  static String _earnedLabel(AppLanguage lang) {
    final m = DateTime.now().month;
    const ru = [
      'Январе',
      'Феврале',
      'Марте',
      'Апреле',
      'Мае',
      'Июне',
      'Июле',
      'Августе',
      'Сентябре',
      'Октябре',
      'Ноябре',
      'Декабре',
    ];
    const uz = [
      'yanvarda',
      'fevralda',
      'martda',
      'aprelda',
      'mayda',
      'iyunda',
      'iyulda',
      'avgustda',
      'sentabrda',
      'oktabrda',
      'noyabrda',
      'dekabrda',
    ];
    const en = [
      'in Jan',
      'in Feb',
      'in Mar',
      'in Apr',
      'in May',
      'in Jun',
      'in Jul',
      'in Aug',
      'in Sep',
      'in Oct',
      'in Nov',
      'in Dec',
    ];
    return tr(
      lang,
      '${uz[m - 1]} ishlangan',
      'Заработано в ${ru[m - 1]}',
      'Earned ${en[m - 1]}',
    );
  }

  /// Operations list card.
  Widget _operationsCard() {
    final lang = LocaleController.language.value;
    return GlassContainer(
      width: double.infinity,
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Operatsiyalar', 'Операции', 'Operations'),
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          if (_txns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                tr(lang, 'Operatsiyalar yoʻq', 'Операций нет', 'No operations'),
                style: const TextStyle(color: _gray),
              ),
            ),
          for (var i = 0; i < _txns.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _txnTile(_txns[i], lang),
          ],
        ],
      ),
    );
  }

  Widget _txnTile(WalletTx txn, AppLanguage lang) {
    final d = txn.createdAt?.toLocal();
    final date = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final positive = txn.amount >= 0;
    return GlassContainer.lite(
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _txLabel(txn.type, lang),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  date,
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
            '${positive ? '+' : ''}${_money(txn.amount)}',
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w700,
              color: positive ? AppColors.blue : const Color(0xFFEF4444),
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
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            style: const TextStyle(fontSize: 11, color: Color(0xFF8D96A4)),
          ),
        ],
      ),
    );
  }
}
