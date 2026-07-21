import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';
import 'package:fixleo/features/wallet/presentation/add_card_screen.dart';

/// Client payment methods ("Кошелек"). Clients have no prepaid balance in the
/// backend — they pay per order by card — so this screen lists the client's
/// REAL saved cards (GET /clients/me/cards) and lets them add/remove one. It no
/// longer shows a fabricated balance or fake transaction history.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _navy900 = Color(0xFF0F172A);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _gray = Color(0xFF8D96A4);

  final PaymentService _payments = PaymentService(kind: 'client');

  List<SavedCard> _cards = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _payments.cards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openAddCard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (mounted) _load(); // reflect a freshly added card
  }

  Future<void> _deleteCard(SavedCard card) async {
    try {
      await _payments.deleteCard(card.id);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Toʻlov kartalari', 'Карты оплаты', 'Payment cards'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _headerCard(lang),
              const SizedBox(height: 10),
              _addCard(lang),
              const SizedBox(height: 10),
              _cardsSection(lang),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark summary card — shows the real card count (no fabricated balance).
  Widget _headerCard(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _navy900,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(lang, 'Saqlangan kartalar', 'Сохранённые карты', 'Saved cards'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: Color(0xFFEDEBFC),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _loading ? '—' : '${_cards.length}',
                style: const TextStyle(
                  fontSize: 32,
                  height: 38 / 32,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.credit_card_outlined, size: 26, color: Colors.white),
        ],
      ),
    );
  }

  /// "Add card" outlined pill (real AddCardScreen).
  Widget _addCard(AppLanguage lang) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openAddCard,
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

  Widget _cardsSection(AppLanguage lang) {
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
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              tr(lang, 'Mening kartalarim', 'Мои карты', 'My cards'),
              style: const TextStyle(
                fontSize: 20,
                height: 24 / 20,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _placeholder(_error!)
          else if (_cards.isEmpty)
            _placeholder(tr(lang, 'Hali karta qoʻshilmagan',
                'Пока нет сохранённых карт', 'No saved cards yet'))
          else
            for (var i = 0; i < _cards.length; i++) ...[
              if (i != 0) const SizedBox(height: 8),
              _cardTile(_cards[i], lang),
            ],
        ],
      ),
    );
  }

  Widget _placeholder(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 20 / 14, color: _gray),
        ),
      ),
    );
  }

  Widget _cardTile(SavedCard card, AppLanguage lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card, size: 22, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.brand.toUpperCase()} •••• ${card.last4}',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                if (card.isDefault)
                  Text(
                    tr(lang, 'Asosiy', 'По умолчанию', 'Default'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      letterSpacing: -0.16,
                      color: AppColors.blue,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 22, color: _gray),
            onPressed: () => _deleteCard(card),
          ),
        ],
      ),
    );
  }
}
