import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// First step of the "add card" flow — card number, expiry and CVV.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _number = TextEditingController(text: '8600 0604 2144 1917');
  final _expiry = TextEditingController(text: '12/12');
  final _cvv = TextEditingController(text: '123');

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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AddCardSmsScreen(maskedPhone: '+998 *** ** 67'),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberFormatter(),
                      ],
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
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Formats a card number as `#### #### #### ####` while typing.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 16 ? digits.substring(0, 16) : digits;
    final formatted = _format(trimmed);
    final selectionIndex = _selectionIndex(
      formatted,
      trimmed.length,
      newValue.selection.extentOffset,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
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

  int _selectionIndex(String formatted, int digitCount, int rawSelection) {
    if (digitCount == 0) return 0;

    var digitsSeen = 0;
    var offset = 0;
    for (final rune in formatted.runes) {
      if (digitsSeen >= digitCount) break;
      offset++;
      if (String.fromCharCode(rune) != ' ') {
        digitsSeen++;
      }
    }

    final desired = rawSelection.clamp(0, formatted.length);
    if (desired < formatted.length) {
      return desired;
    }
    return offset;
  }
}

/// Second step — SMS code confirmation.
class AddCardSmsScreen extends StatefulWidget {
  const AddCardSmsScreen({super.key, required this.maskedPhone});

  final String maskedPhone;

  @override
  State<AddCardSmsScreen> createState() => _AddCardSmsScreenState();
}

class _AddCardSmsScreenState extends State<AddCardSmsScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  Timer? _timer;

  int _secondsLeft = 59;
  String? _error;

  static const _validCode = '5834';

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

  void _submit() {
    if (_code.length != 4) return;
    if (_code == _validCode) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AddCardSuccessScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AddCardFailureScreen()),
      );
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
              label: tr(lang, 'Tasdiqlash', 'Подтвердить', 'Confirm'),
              onPressed: _code.length == 4 ? _submit : null,
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

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.blue.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            counterText: '',
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
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
              onPressed: () => Navigator.of(context).pop(),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
