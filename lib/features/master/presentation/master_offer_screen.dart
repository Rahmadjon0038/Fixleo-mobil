import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_offer_sent_screen.dart';

/// Master's offer for a request — price type, amount and a note to the
/// client, submitted via `POST /masters/me/feed/:orderId/offer`.
class MasterOfferScreen extends StatefulWidget {
  const MasterOfferScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<MasterOfferScreen> createState() => _MasterOfferScreenState();
}

class _MasterOfferScreenState extends State<MasterOfferScreen> {
  static const _typeCodes = ['fixed', 'range', 'after_inspection'];

  final _price = TextEditingController(text: '50 000');
  final _comment = TextEditingController();
  final MasterMarketplaceService _market = MasterMarketplaceService();
  int _type = 0;
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = LocaleController.language.value;
    final priceType = _typeCodes[_type.clamp(0, 2)];
    int? price;
    if (priceType != 'after_inspection') {
      price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(lang, 'Narxni kiriting', 'Введите цену', 'Enter a price'),
            ),
          ),
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await _market.makeOffer(
        widget.orderId,
        priceType: priceType,
        price: price,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MasterOfferSentScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final types = [
      tr(lang, 'Fiks', 'Фикс', 'Fixed'),
      tr(lang, 'Diapazon', 'Диапазон', 'Range'),
      tr(lang, 'Koʻrgandan keyin', 'После осмотра', 'After inspection'),
    ];
    // Demo (app-store/Play-Market review) master — never show a price field.
    // `_type` stays at its default (0 = fixed) and `_price` keeps its default
    // placeholder text, so `_submit()` still sends a valid offer underneath.
    final isDemo = CurrentUser.instance.isDemo;
    return BrandedScaffold(
      title: tr(lang, 'Sizning taklifingiz', 'Ваше предложение', 'Your offer'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDemo) ...[
              // Price type.
              _Card(
                title: tr(lang, 'Narx turi', 'Тип цены', 'Price type'),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeChip(
                        label: types[0],
                        selected: _type == 0,
                        onTap: () => setState(() => _type = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TypeChip(
                        label: types[1],
                        selected: _type == 1,
                        onTap: () => setState(() => _type = 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: types[2],
                      selected: _type == 2,
                      onTap: () => setState(() => _type = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Price amount.
              _Card(
                title: tr(lang, 'Sizning narxingiz', 'Ваша цена', 'Your price'),
                child: GlassTextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandsSeparatorInputFormatter()],
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                  trailing: Text(
                    tr(lang, 'soʻm', 'сум', 'sum'),
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Comment.
            _Card(
              title: tr(
                lang,
                'Mijozga izoh',
                'Комментарий клиенту',
                'Note to the client',
              ),
              child: GlassTextField(
                controller: _comment,
                height: 110,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textStyle: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: AppColors.navy,
                ),
                hintText: tr(
                  lang,
                  'Masalan: Bir soat ichida yetib bora olaman.',
                  'Например: могу подъехать в течение часа.',
                  'For example: I can arrive within an hour.',
                ),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: _busy
                  ? tr(lang, 'Yuborilmoqda…', 'Отправка…', 'Sending…')
                  : tr(
                      lang,
                      'Javobni yuborish',
                      'Отправить ответ',
                      'Send reply',
                    ),
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a monetary amount grouped from the right: `200000000` becomes
/// `200 000 000`. Non-digit input is ignored and the caret stays beside the
/// same digit when editing in the middle of the amount.
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final baseDigitCount = _digitCountBefore(
      newValue.text,
      newValue.selection.baseOffset,
    );
    final extentDigitCount = _digitCountBefore(
      newValue.text,
      newValue.selection.extentOffset,
    );
    final formatted = _format(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _offsetAfterDigits(formatted, baseDigitCount),
        extentOffset: _offsetAfterDigits(formatted, extentDigitCount),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }

  int _digitCountBefore(String text, int rawOffset) {
    final offset = rawOffset.clamp(0, text.length);
    return text.substring(0, offset).replaceAll(_nonDigits, '').length;
  }

  String _format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  int _offsetAfterDigits(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;

    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted.codeUnitAt(i) != 0x20) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return formatted.length;
  }
}

/// Frosted glass section card with a semibold title and content below.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23232E),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Pill chip for the price-type row.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: selected ? Colors.white : AppColors.navy,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: selected
          ? GlassContainer.tinted(
              borderRadius: 999,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: text,
            )
          : GlassContainer.lite(
              tint: const Color(0xFFF1F5F9),
              borderRadius: 999,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: text,
            ),
    );
  }
}
