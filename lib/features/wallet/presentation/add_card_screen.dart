import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/wallet/data/payment_service.dart';

/// Only a successful server-side OTP confirmation saves a card.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key, this.kind = 'client', this.payments});
  final String kind;
  final PaymentService? payments;

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _otp = TextEditingController();
  final _numberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _otpFocus = FocusNode();
  late final _payments = widget.payments ?? PaymentService(kind: widget.kind);
  String? _bindingId;
  String? _phone;
  String? _error;
  String _last4 = '';
  bool _busy = false;
  bool _numberTouched = false;
  bool _expiryTouched = false;
  Timer? _timer;
  DateTime? _retryAt;

  AppLanguage get _lang => LocaleController.language.value;
  bool get _confirming => _bindingId != null;
  String get _pan => _number.text.replaceAll(' ', '');
  int get _wait => _retryAt == null
      ? 0
      : ((_retryAt!.difference(DateTime.now()).inMilliseconds + 999) ~/ 1000)
            .clamp(0, 60);
  String _t(String uz, String ru, String en) => tr(_lang, uz, ru, en);

  @override
  void initState() {
    super.initState();
    _numberFocus.addListener(_onNumberFocus);
    _expiryFocus.addListener(_onExpiryFocus);
  }

  void _onNumberFocus() {
    if (!_numberFocus.hasFocus && mounted) {
      setState(() => _numberTouched = true);
    }
  }

  void _onExpiryFocus() {
    if (!_expiryFocus.hasFocus && mounted) {
      setState(() => _expiryTouched = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _numberFocus.removeListener(_onNumberFocus);
    _expiryFocus.removeListener(_onExpiryFocus);
    _numberFocus.dispose();
    _expiryFocus.dispose();
    _otpFocus.dispose();
    _number.dispose();
    _expiry.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? get _numberError {
    if (!_numberTouched && _pan.length < 16) return null;
    if (_pan.isEmpty) return null;
    if (_pan.length != 16) {
      return _t(
        '16 xonali raqamni to‘liq kiriting',
        'Введите все 16 цифр номера',
        'Enter all 16 card digits',
      );
    }
    if (!RegExp(r'^(8600|5614|9860)').hasMatch(_pan)) {
      return _t(
        'Uzcard yoki Humo kartasini kiriting',
        'Введите номер карты Uzcard или Humo',
        'Use an Uzcard or Humo card',
      );
    }
    return null;
  }

  bool get _expiryValid {
    final parts = _expiry.text.split('/');
    if (parts.length != 2 || parts.any((p) => p.length != 2)) return false;
    final month = int.tryParse(parts[0]) ?? 0;
    final year = 2000 + (int.tryParse(parts[1]) ?? 0);
    if (month < 1 || month > 12) return false;
    return DateTime.utc(year, month + 1).isAfter(DateTime.now().toUtc());
  }

  String? get _expiryError {
    if (_expiry.text.isEmpty ||
        (!_expiryTouched && _expiry.text.length < 5) ||
        _expiryValid) {
      return null;
    }
    return _t(
      'Kartadagi amal qilish muddatini tekshiring',
      'Проверьте срок действия карты',
      'Check the expiry printed on your card',
    );
  }

  bool get _valid => _confirming
      ? RegExp(r'^\d{6}$').hasMatch(_otp.text)
      : RegExp(r'^(8600|5614|9860)\d{12}$').hasMatch(_pan) && _expiryValid;

  void _startWait() {
    _retryAt = DateTime.now().add(const Duration(seconds: 60));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_wait == 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (_busy || !_valid || _wait > 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_confirming) {
        final parts = _expiry.text.split('/');
        final last4 = _pan.substring(12);
        final result = await _payments.bindCard(_pan, '${parts[1]}${parts[0]}');
        if (!mounted) return;
        setState(() {
          _bindingId = result['bindingId'] as String;
          _phone = result['phone'] as String?;
          _last4 = last4;
        });
        // Keep only the masked card reference for the confirmation step.
        _number.clear();
        _expiry.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocus.requestFocus();
        });
      } else {
        await _payments.confirmCard(_bindingId!, _otp.text);
        if (!mounted) return;
        _otp.clear();
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // The deployed API currently returns localized text, not a cooldown code.
      // Do not interpret other 409s (including unknown bank outcomes) as retries.
      final isBindingWait =
          !_confirming &&
          e.statusCode == 409 &&
          (e.message.contains('Karta uchun kod yuborilgan.') ||
              e.message.contains('Код уже отправлен.') ||
              e.message.contains('A code was already sent.'));
      setState(() {
        _error = e.message;
        if (isBindingWait) _startWait();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t(
          'Natijani aniqlab bo‘lmadi. Qayta yuborishdan oldin kartalar ro‘yxatini tekshiring.',
          'Не удалось проверить результат. Перед повторной попыткой проверьте список карт.',
          'The result could not be verified. Check your cards before trying again.',
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _confirming;
    return BrandedScaffold(
      title: _t('Karta qo‘shish', 'Добавление карты', 'Add card'),
      showBack: true,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 36).clamp(0, double.infinity),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _steps(),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LiquidSurface(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      confirming
                          ? Icons.sms_outlined
                          : Icons.credit_card_rounded,
                      size: 28,
                      color: AppColors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  confirming
                      ? _t(
                          'SMS bilan tasdiqlang',
                          'Подтвердите по SMS',
                          'Confirm with SMS',
                        )
                      : _t(
                          'Kartangizni qo‘shing',
                          'Добавьте вашу карту',
                          'Add your card',
                        ),
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  confirming
                      ? _t(
                          'Bank yuborgan 6 xonali kodni kiriting.',
                          'Введите 6-значный код от банка.',
                          'Enter the 6-digit code from your bank.',
                        )
                      : _t(
                          'Uzcard yoki Humo. Faqat karta raqami va amal qilish muddati kerak.',
                          'Uzcard или Humo. Нужны только номер карты и срок действия.',
                          'Uzcard or Humo. Just your card number and expiry date.',
                        ),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                if (!confirming) ...[
                  _field(
                    key: 'card-number',
                    controller: _number,
                    focus: _numberFocus,
                    label: _t('Karta raqami', 'Номер карты', 'Card number'),
                    hint: '0000 0000 0000 0000',
                    formatters: [_GroupedDigitsFormatter(16, 4, ' ')],
                    error: _numberError,
                    action: TextInputAction.next,
                    onSubmitted: (_) => _expiryFocus.requestFocus(),
                    trailing: _pan.startsWith('9860')
                        ? 'HUMO'
                        : (_pan.startsWith('8600') || _pan.startsWith('5614'))
                        ? 'UZCARD'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _field(
                    key: 'card-expiry',
                    controller: _expiry,
                    focus: _expiryFocus,
                    label: _t(
                      'Amal qilish muddati',
                      'Срок действия',
                      'Expiry date',
                    ),
                    hint: _t('OO/YY', 'ММ/ГГ', 'MM/YY'),
                    formatters: [_GroupedDigitsFormatter(4, 2, '/')],
                    error: _expiryError,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    trailing: _t('oy / yil', 'месяц / год', 'month / year'),
                  ),
                ] else ...[
                  GlassContainer.lite(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.credit_card_rounded,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '••••  $_last4',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _phone ??
                                    _t(
                                      'Kartaga ulangan telefon',
                                      'Телефон, привязанный к карте',
                                      'Your card’s phone number',
                                    ),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field(
                    key: 'card-otp',
                    controller: _otp,
                    focus: _otpFocus,
                    label: _t('SMS kodi', 'Код из SMS', 'SMS code'),
                    hint: '••••••',
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    action: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    otp: true,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Semantics(
                    liveRegion: true,
                    child: LiquidSurface(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2ED),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: Color(0xFF9A4525),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF9A4525),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_busy) ...[
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: _busy
                      ? _t(
                          'Bank javobi kutilmoqda…',
                          'Ожидаем ответ банка…',
                          'Waiting for your bank…',
                        )
                      : _wait > 0
                      ? _t(
                          '$_wait soniya kuting',
                          'Подождите $_wait сек',
                          'Wait $_wait sec',
                        )
                      : confirming
                      ? _t('Kartani qo‘shish', 'Добавить карту', 'Add card')
                      : _t(
                          'SMS kodini olish',
                          'Получить SMS-код',
                          'Get SMS code',
                        ),
                  onPressed: !_busy && _valid && _wait == 0 ? _submit : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        confirming
                            ? _t(
                                'Karta faqat to‘g‘ri SMS kodi bilan qo‘shiladi.',
                                'Карта добавится только после проверки SMS-кода.',
                                'Your card is added only after the SMS code is verified.',
                              )
                            : _t(
                                'CVV va PIN-kod kerak emas.',
                                'CVV и PIN-код не нужны.',
                                'No CVV or PIN required.',
                              ),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                if (confirming) ...[
                  const SizedBox(height: 14),
                  LiquidMaterial(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: Text(
                        _t(
                          'Kod kelmadimi?',
                          'Код не пришёл?',
                          'Didn’t receive a code?',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      children: [
                        Text(
                          _t(
                            'Kartaga ulangan telefon SMSlarini tekshiring. Kod biroz kechikishi mumkin. Kartani boshqa qurilmada qo‘shgan bo‘lsangiz, kartalar ro‘yxatiga qayting.',
                            'Проверьте SMS на телефоне, привязанном к карте. Код может прийти с задержкой. Если вы добавили карту на другом устройстве, вернитесь к списку карт.',
                            'Check SMS on the phone linked to your card. The code may take a moment. If you added this card on another device, return to your cards.',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _steps() => Row(
    children: [
      Expanded(child: _step(1, _t('Karta', 'Карта', 'Card'), true)),
      LiquidSurface(
        width: 24,
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppColors.blue.withValues(alpha: .25),
      ),
      Expanded(
        child: _step(
          2,
          _t('Tasdiqlash', 'Подтверждение', 'Verify'),
          _confirming,
        ),
      ),
    ],
  );

  Widget _step(int number, String label, bool active) => Row(
    children: [
      LiquidSurface(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.blue : const Color(0xFFE2E8F0),
        ),
        alignment: Alignment.center,
        child: number == 1 && _confirming
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : Text(
                '$number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : const Color(0xFF64748B),
                ),
              ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.navy : const Color(0xFF64748B),
          ),
        ),
      ),
    ],
  );

  Widget _field({
    required String key,
    required TextEditingController controller,
    required FocusNode focus,
    required String label,
    required String hint,
    required List<TextInputFormatter> formatters,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
    String? error,
    String? trailing,
    bool otp = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
      const SizedBox(height: 8),
      GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shadow: false,
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          focusNode: focus,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textInputAction: action,
          inputFormatters: formatters,
          autofillHints: otp ? const [AutofillHints.oneTimeCode] : null,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: otp ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: otp ? 28 : 18,
            fontWeight: FontWeight.w600,
            letterSpacing: otp ? 8 : .5,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: otp ? 28 : 17,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            suffixIcon: trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      trailing,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            suffixIconConstraints: const BoxConstraints(minHeight: 16),
          ),
          onSubmitted: onSubmitted,
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ),
    ],
  );
}

/// Groups pasted/typed digits while preserving caret position during edits.
class _GroupedDigitsFormatter extends TextInputFormatter {
  _GroupedDigitsFormatter(this.limit, this.group, this.separator);
  final int limit;
  final int group;
  final String separator;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text;
    var caret = newValue.selection.extentOffset.clamp(0, raw.length);
    // Backspace at a separator must delete the preceding digit, not get stuck.
    if (oldValue.text.length == raw.length + 1 &&
        oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        caret > 0 &&
        caret < oldValue.text.length &&
        oldValue.text[caret] == separator) {
      raw = raw.replaceRange(caret - 1, caret, '');
      caret--;
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.substring(0, digits.length.clamp(0, limit));
    final text = [
      for (var i = 0; i < trimmed.length; i += group)
        trimmed.substring(i, (i + group).clamp(0, trimmed.length)),
    ].join(separator);
    final before = raw.substring(0, caret).replaceAll(RegExp(r'\D'), '').length;
    final offset = (before + (before > 0 ? (before - 1) ~/ group : 0)).clamp(
      0,
      text.length,
    );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
