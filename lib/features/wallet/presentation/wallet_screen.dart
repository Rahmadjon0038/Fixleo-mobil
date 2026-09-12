import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';
import 'package:fixleo/features/wallet/presentation/add_card_screen.dart';

/// Client «Кошелек» (FINAL design): dark balance card with «Пополнить» /
/// «История», the operations feed, plus saved-card management. The balance
/// and operations are real (`GET /clients/me/wallet[…]`); top-up charges the
/// selected saved card through the mock provider.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

/// "125 000" — so'm amount with thousands separators.
String _fmtSum(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

/// "Сегодня, 14:30" for today, "21.07, 14:30" otherwise.
String _fmtOpDate(AppLanguage lang, DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(local.hour)}:${two(local.minute)}';
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    return '${tr(lang, 'Bugun', 'Сегодня', 'Today')}, $hm';
  }
  return '${two(local.day)}.${two(local.month)}, $hm';
}

class _WalletScreenState extends State<WalletScreen> {
  static const _gray = Color(0xFF8D96A4);

  final PaymentService _payments = PaymentService(kind: 'client');
  final GlobalKey _operationsKey = GlobalKey();

  List<SavedCard> _cards = const [];
  List<WalletOperation> _operations = const [];
  int? _balance;
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
      final results = await Future.wait([
        _payments.walletBalance(),
        _payments.walletOperations(),
        _payments.cards(),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as int;
        _operations = results[1] as List<WalletOperation>;
        _cards = results[2] as List<SavedCard>;
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCardScreen()));
    if (mounted) _load();
  }

  Future<void> _deleteCard(SavedCard card) async {
    final lang = LocaleController.language.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: Text(
          tr(lang, 'Kartani oʻchirish', 'Удалить карту', 'Delete card'),
        ),
        content: Text(
          tr(
            lang,
            '${card.brand.toUpperCase()} •••• ${card.last4} oʻchirilsinmi? Bu amalni bekor qilib boʻlmaydi.',
            'Удалить ${card.brand.toUpperCase()} •••• ${card.last4}? Это действие нельзя отменить.',
            'Delete ${card.brand.toUpperCase()} •••• ${card.last4}? This can\'t be undone.',
          ),
        ),
        actions: [
          LiquidActionButton.text(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(lang, 'Bekor qilish', 'Отмена', 'Cancel')),
          ),
          LiquidActionButton.text(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              tr(lang, 'Oʻchirish', 'Удалить', 'Delete'),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _payments.deleteCard(card.id);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _scrollToOperations() {
    final ctx = _operationsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openTopupSheet() async {
    final lang = LocaleController.language.value;
    if (_cards.isEmpty) {
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Avval karta qoʻshing',
              'Сначала добавьте карту',
              'Add a card first',
            ),
          ),
        ),
      );
      return;
    }
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopupSheet(payments: _payments, cards: _cards),
    );
    if (done == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Hamyon', 'Кошелек', 'Wallet'),
      showBack: !widget.embedded,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: widget.embedded ? 100 : 20),
            children: [
              _balanceCard(lang),
              const SizedBox(height: 10),
              _addCard(lang),
              const SizedBox(height: 10),
              _operationsSection(lang),
              const SizedBox(height: 10),
              _cardsSection(lang),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark card — «Баланс карты» + amount + [Пополнить][История] (FINAL).
  /// Flat, not glass — matches the FINAL Figma wallet page exactly.
  Widget _balanceCard(AppLanguage lang) {
    return LiquidSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.heroDark,
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
                size: 22,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _loading || _balance == null
                ? '—'
                : '${_fmtSum(_balance!)} ${tr(lang, 'soʻm', 'сум', 'sum')}',
            style: const TextStyle(
              fontSize: 32,
              height: 38 / 32,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: LiquidActionButton.filled(
                    onPressed: _openTopupSheet,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.heroDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr(lang, 'Toʻldirish', 'Пополнить', 'Top up'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: LiquidActionButton.filled(
                    onPressed: _scrollToOperations,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF39414E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr(lang, 'Tarix', 'История', 'History'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Add card" glass pill (real AddCardScreen).
  Widget _addCard(AppLanguage lang) {
    return GestureDetector(
      onTap: _openAddCard,
      child: GlassContainer(
        borderRadius: 40,
        height: 52,
        alignment: Alignment.center,
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
    );
  }

  /// «Операции» — merged money history (FINAL).
  Widget _operationsSection(AppLanguage lang) {
    return GlassContainer(
      key: _operationsKey,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              tr(lang, 'Operatsiyalar', 'Операции', 'Operations'),
              style: const TextStyle(
                fontSize: 17,
                height: 24 / 17,
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
          else if (_operations.isEmpty)
            _placeholder(
              tr(
                lang,
                'Hozircha operatsiyalar yoʻq',
                'Пока нет операций',
                'No operations yet',
              ),
            )
          else
            for (var i = 0; i < _operations.length; i++) ...[
              if (i != 0) const SizedBox(height: 8),
              _operationTile(_operations[i], lang),
            ],
        ],
      ),
    );
  }

  String _opTitle(WalletOperation op, AppLanguage lang) {
    final subject = op.categoryName ?? op.orderTitle;
    switch (op.kind) {
      case 'topup':
        final card = op.note == null ? '' : ' · ${op.note}';
        return '${tr(lang, 'Toʻldirish', 'Пополнение', 'Top-up')}$card';
      case 'card_payment':
      case 'order_payment':
        return '${tr(lang, 'Toʻlov', 'Оплата', 'Payment')}${subject == null ? '' : ' — $subject'}';
      case 'card_refund':
      case 'refund':
        return '${tr(lang, 'Qaytarish', 'Возврат', 'Refund')}${subject == null ? '' : ' — $subject'}';
      default:
        return tr(lang, 'Korreksiya', 'Корректировка', 'Adjustment');
    }
  }

  Widget _operationTile(WalletOperation op, AppLanguage lang) {
    return GlassContainer.lite(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _opTitle(op, lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtOpDate(lang, op.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: _gray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${op.amount > 0 ? '+' : ''}${_fmtSum(op.amount)}',
            style: const TextStyle(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardsSection(AppLanguage lang) {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              tr(lang, 'Mening kartalarim', 'Мои карты', 'My cards'),
              style: const TextStyle(
                fontSize: 17,
                height: 24 / 17,
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
          else if (_cards.isEmpty)
            _placeholder(
              tr(
                lang,
                'Hali karta qoʻshilmagan',
                'Пока нет сохранённых карт',
                'No saved cards yet',
              ),
            )
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
    return GlassContainer.lite(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
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
          LiquidIconControl(
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 22, color: _gray),
              onPressed: () => _deleteCard(card),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Пополнить» bottom sheet — amount + card picker → mock top-up.
class _TopupSheet extends StatefulWidget {
  const _TopupSheet({required this.payments, required this.cards});

  final PaymentService payments;
  final List<SavedCard> cards;

  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  final String _requestKey = const Uuid().v4();
  final _amountController = TextEditingController();
  late int _cardId = widget.cards
      .firstWhere((c) => c.isDefault, orElse: () => widget.cards.first)
      .id;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = LocaleController.language.value;
    final amount = int.tryParse(_amountController.text.replaceAll(' ', ''));
    if (amount == null || amount < 1000) {
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Kamida 1 000 soʻm kiriting',
              'Минимум 1 000 сум',
              'Minimum 1 000 sum',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.payments.topup(
        cardId: _cardId,
        amount: amount,
        requestKey: _requestKey,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    // Same top-rounded frosted-glass panel construction as
    // showGlassModalBottomSheet (glass_sheet.dart) — reproduced locally
    // because that helper always rounds all four corners via GlassContainer,
    // while a bottom sheet needs only the top corners rounded, and the
    // caller here (WalletScreen._openTopupSheet) already passes
    // backgroundColor: Colors.transparent into a plain showModalBottomSheet.
    return LiquidSurface(
      margin: EdgeInsets.only(bottom: bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: GlassBackdrop(
          child: LiquidSurface(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(
                    alpha: usesNativeLiquidGlass(context)
                        ? 0
                        : usesGlassMaterial(context)
                        ? .80
                        : 1,
                  ),
                  Colors.white.withValues(
                    alpha: usesNativeLiquidGlass(context)
                        ? 0
                        : usesGlassMaterial(context)
                        ? .66
                        : 1,
                  ),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: LiquidSurface(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(
                    lang,
                    'Hamyonni toʻldirish',
                    'Пополнить кошелёк',
                    'Top up wallet',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                  hintText: tr(
                    lang,
                    'Summa (soʻm)',
                    'Сумма (сум)',
                    'Amount (sum)',
                  ),
                ),
                const SizedBox(height: 12),
                for (final card in widget.cards) ...[
                  GestureDetector(
                    onTap: () => setState(() => _cardId = card.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _cardId == card.id
                          ? GlassContainer.tinted(
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: _topupCardRow(card),
                            )
                          : GlassContainer.lite(
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: _topupCardRow(card),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _submitButton(lang),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Built directly on [GlassContainer] (rather than [GlassButton]) so the
  /// busy state can swap in a spinner, same as before — the tint/opacity
  /// values mirror GlassButtonVariant.primary.
  Widget _submitButton(AppLanguage lang) {
    final glass = GlassContainer(
      tint: AppColors.blue,
      tintOpacityTop: 0.90,
      tintOpacityBottom: 0.74,
      borderOpacity: 0.5,
      borderRadius: 14,
      height: 52,
      shadow: !_busy,
      shadowColor: AppColors.blue,
      alignment: Alignment.center,
      child: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Text(
              tr(lang, 'Toʻldirish', 'Пополнить', 'Top up'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Semantics(
        button: true,
        enabled: !_busy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : _submit,
          child: ExcludeSemantics(child: glass),
        ),
      ),
    );
  }

  Widget _topupCardRow(SavedCard card) {
    return Row(
      children: [
        const Icon(Icons.credit_card, size: 20, color: AppColors.navy),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${card.brand.toUpperCase()} •••• ${card.last4}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
        Icon(
          _cardId == card.id
              ? Icons.radio_button_checked
              : Icons.radio_button_off,
          size: 20,
          color: _cardId == card.id ? AppColors.blue : Colors.grey,
        ),
      ],
    );
  }
}
