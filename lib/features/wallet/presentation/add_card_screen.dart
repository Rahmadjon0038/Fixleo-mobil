import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';

/// "+998901234567" -> "+998 *** ** 67" — keeps the dial code and the last
/// two digits visible, masks the rest. Used on the SMS confirmation screen.
String _maskPhone(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 5) return raw ?? '';
  final codeLen = switch (digits) {
    String s when s.startsWith('998') => 3,
    String s when s.startsWith('996') => 3,
    String s when s.startsWith('992') => 3,
    String s when s.startsWith('7') => 1,
    _ => digits.length > 9 ? digits.length - 9 : 1,
  };
  final code = digits.substring(0, codeLen);
  final local = digits.substring(codeLen);
  if (local.length <= 2) return '+$code $local';
  final last2 = local.substring(local.length - 2);
  return '+$code ${'*' * (local.length - 2)} $last2';
}

/// Guesses a card brand from its number prefix, for the backend `addCard`
/// payload. Must match the backend's `CardBrand` enum exactly — lowercase,
/// one of visa/mastercard/uzcard/humo (UzCard/Humo are the common
/// local-issued cards; anything unrecognized defaults to uzcard, the most
/// common local card, since the enum has no generic "other" value).
String _detectBrand(String digits) {
  if (digits.startsWith('9860')) return 'humo';
  if (digits.startsWith('4')) return 'visa';
  if (digits.startsWith('5')) return 'mastercard';
  return 'uzcard';
}

/// First step of the "add card" flow — card number, expiry and CVV.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _number.text.replaceAll(RegExp(r'\D'), '').length == 16 &&
      RegExp(r'^\d{2}/\d{2}$').hasMatch(_expiry.text.trim()) &&
      _cvv.text.trim().length == 3;

  void _continue() {
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    // push, not pushReplacement — replacing this route would immediately
    // complete WalletScreen's `await Navigator.push(AddCardScreen())`
    // (before the card is even created), so its post-flow refresh fired too
    // early and the new card never showed up in the list.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCardSmsScreen(
          maskedPhone: _maskPhone(CurrentUser.instance.profile.value?.phone),
          brand: _detectBrand(digits),
          last4: digits.substring(digits.length - 4),
          expiry: _expiry.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Karta qoʻshish', 'Добавление карты', 'Add card'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(
                      tr(lang, 'Karta raqami', 'Номер карты', 'Card number'),
                    ),
                    _textField(
                      controller: _number,
                      hint: '1234 5678 9101 1213',
                      keyboardType: TextInputType.number,
                      inputFormatters: [_CardNumberFormatter()],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(
                                tr(
                                  lang,
                                  'Amal qilish muddati',
                                  'Срок действия',
                                  'Expiry date',
                                ),
                              ),
                              _textField(
                                controller: _expiry,
                                hint: '12/12',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9/]'),
                                  ),
                                  LengthLimitingTextInputFormatter(5),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('CVV'),
                              _textField(
                                controller: _cvv,
                                hint: '123',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PrimaryButton(
              label: tr(lang, 'Tasdiqlash', 'Подтвердить', 'Confirm'),
              onPressed: _isValid ? _continue : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: AppColors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
  }) {
    return GlassTextField(
      controller: controller,
      height: 48,
      hintText: hint,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (_) => setState(() {}),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
    );
  }
}

/// Formats a card number as `#### #### #### ####` while typing, capped at 16
/// digits. Does its own digit-filtering and length-limiting (instead of
/// being chained after separate formatters for those) so it can tell a real
/// edit apart from a pure cursor move.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Pure cursor/selection move (arrow keys, tap) — the text is unchanged,
    // so leave the selection exactly as the platform placed it. Re-deriving
    // it from a digit count would collapse the "before the space" / "after
    // the space" cursor positions into one, which made left/right
    // navigation get stuck at the space between digit groups.
    if (newValue.text == oldValue.text) return newValue;

    final digitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 16 ? digits.substring(0, 16) : digits;
    final formatted = _format(trimmed);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetForDigitCount(
          formatted,
          digitsBeforeCursor.clamp(0, trimmed.length),
        ),
      ),
    );
  }

  String _format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// The offset in [formatted] that sits right after its [count]-th digit
  /// character (skipping over the grouping spaces, which don't count).
  int _offsetForDigitCount(String formatted, int count) {
    if (count <= 0) return 0;
    var digitsSeen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] == ' ') continue;
      digitsSeen++;
      if (digitsSeen == count) return i + 1;
    }
    return formatted.length;
  }
}

/// Second step — SMS code confirmation.
class AddCardSmsScreen extends StatefulWidget {
  const AddCardSmsScreen({
    super.key,
    required this.maskedPhone,
    required this.brand,
    required this.last4,
    required this.expiry,
  });

  final String maskedPhone;
  final String brand;
  final String last4;
  final String expiry;

  @override
  State<AddCardSmsScreen> createState() => _AddCardSmsScreenState();
}

class _AddCardSmsScreenState extends State<AddCardSmsScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  final _payments = PaymentService(kind: 'client');
  Timer? _timer;

  int _secondsLeft = 59;
  String? _error;
  bool _submitting = false;

  static const _validCode = '1111';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (_error != null) setState(() => _error = null);
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == 4) {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_code.length != 4 || _submitting) return;
    if (_code != _validCode) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AddCardFailureScreen()));
      return;
    }
    setState(() => _submitting = true);
    try {
      // Actually persists the card server-side — without this call the
      // "success" screen was purely cosmetic and the wallet's card list
      // stayed empty after returning to it.
      await _payments.addCard(
        brand: widget.brand,
        last4: widget.last4,
        expiry: widget.expiry,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AddCardSuccessScreen()));
    } on ApiException {
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AddCardFailureScreen()));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resend() {
    setState(() {
      for (final c in _controllers) {
        c.clear();
      }
      _error = null;
    });
    _focusNodes.first.requestFocus();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Karta qoʻshish', 'Добавление карты', 'Add card'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              tr(
                lang,
                'SMS kodini kiriting',
                'Введите код из SMS',
                'Enter the SMS code',
              ),
              style: const TextStyle(
                fontSize: 24,
                height: 30 / 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                lang,
                'Kod yuborildi: ${widget.maskedPhone}',
                'Код отправлен на ${widget.maskedPhone}',
                'Code sent to ${widget.maskedPhone}',
              ),
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i != 0) const SizedBox(width: 10),
                  _CodeBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    onChanged: (value) => _onChanged(i, value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _secondsLeft > 0
                  ? tr(
                      lang,
                      'Kodni qayta yuborish ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')} dan soʻng',
                      'Отправить код повторно через ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                      'Resend code in ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                    )
                  : tr(
                      lang,
                      'Kod qayta yuborildi',
                      'Код отправлен повторно',
                      'Code resent',
                    ),
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                color: AppColors.muted,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: _submitting
                  ? tr(lang, 'Tekshirilmoqda...', 'Проверка...', 'Verifying...')
                  : tr(lang, 'Tasdiqlash', 'Подтвердить', 'Confirm'),
              onPressed: _code.length == 4 && !_submitting ? _submit : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _secondsLeft == 0 ? _resend : null,
                child: Text(
                  tr(
                    lang,
                    'Kodni qayta yuborish',
                    'Отправить код снова',
                    'Resend code',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatefulWidget {
  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<_CodeBox> createState() => _CodeBoxState();
}

class _CodeBoxState extends State<_CodeBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    // White glass box with the border drawn on a plain fixed-size Container
    // (not via TextField/InputDecoration) — an OutlineInputBorder sizes
    // itself from the decorator's internal content height, which turns a
    // square box into a pill/oval the moment the field is focused.
    return Expanded(
      child: GlassContainer(
        height: 64,
        borderRadius: 18,
        padding: EdgeInsets.zero,
        borderOpacity: 0,
        shadow: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: focused
                  ? AppColors.blue
                  : Colors.white.withValues(alpha: 0.75),
              width: focused ? 2 : 1,
            ),
          ),
          child: Center(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
              cursorColor: AppColors.blue,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              onChanged: widget.onChanged,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Success result screen.
class AddCardSuccessScreen extends StatelessWidget {
  const AddCardSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            const Spacer(),
            GlassCard(
              radius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(44),
                    ),
                    child: const Icon(
                      Icons.verified,
                      size: 44,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      lang,
                      'Karta qoʻshildi',
                      'Карта добавлена',
                      'Card added',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      lang,
                      'Karta roʻyxatga qoʻshildi va saqlandi.',
                      'Карта сохранена и добавлена в список.',
                      'The card has been saved and added to the list.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(
                lang,
                'Hamyonga qaytish',
                'На главную',
                'Back to wallet',
              ),
              // Pops all the way back to the wallet tab (Add/Sms/Success are
              // three separate pushed routes now, not one replaced in place).
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}

/// Failure result screen.
class AddCardFailureScreen extends StatelessWidget {
  const AddCardFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            const Spacer(),
            GlassCard(
              radius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(44),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 40,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      lang,
                      'Karta qoʻshilmadi',
                      'Карта не добавлена',
                      'Card was not added',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      lang,
                      'SMS kodi notoʻgʻri yoki bank tasdiqlamadi.',
                      'SMS-код неверный или банк отклонил запрос.',
                      'The SMS code is wrong or the bank declined the request.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(
                lang,
                'Hamyonga qaytish',
                'На главную',
                'Back to wallet',
              ),
              // Pops all the way back to the wallet tab (Add/Sms/Success are
              // three separate pushed routes now, not one replaced in place).
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
