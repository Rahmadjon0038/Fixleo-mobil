import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/auth/presentation/otp_screen.dart';
import 'package:fixleo/features/master/data/master_service.dart';

/// A selectable country for the phone prefix: flag, short pill label,
/// dial code and how the local number is grouped while typing.
class _Country {
  const _Country({
    required this.flag,
    required this.short,
    required this.nameUz,
    required this.nameRu,
    required this.nameEn,
    required this.dial,
    required this.groups,
    required this.hint,
    this.minDigits,
  });

  final String flag;
  final String short;
  final String nameUz;
  final String nameRu;
  final String nameEn;

  /// Dial code with the leading plus, e.g. `+998`.
  final String dial;

  /// Digit groups for live formatting, e.g. [2, 3, 2, 2] → "90 123 45 67".
  final List<int> groups;

  final String hint;
  final int? minDigits;

  int get digits => groups.fold(0, (a, b) => a + b);
  int get requiredDigits => minDigits ?? digits;
}

const _countries = [
  _Country(
    flag: '🇺🇿',
    short: 'Uzb',
    nameUz: 'Oʻzbekiston',
    nameRu: 'Узбекистан',
    nameEn: 'Uzbekistan',
    dial: '+998',
    groups: [2, 3, 2, 2],
    hint: '90 123 45 67',
  ),
  _Country(
    flag: '🇷🇺',
    short: 'Rus',
    nameUz: 'Rossiya',
    nameRu: 'Россия',
    nameEn: 'Russia',
    dial: '+7',
    groups: [3, 3, 2, 2],
    hint: '900 123 45 67',
  ),
  _Country(
    flag: '🇰🇿',
    short: 'Kaz',
    nameUz: 'Qozogʻiston',
    nameRu: 'Казахстан',
    nameEn: 'Kazakhstan',
    dial: '+7',
    groups: [3, 3, 2, 2],
    hint: '700 123 45 67',
  ),
  _Country(
    flag: '🇰🇬',
    short: 'Kgz',
    nameUz: 'Qirgʻiziston',
    nameRu: 'Кыргызстан',
    nameEn: 'Kyrgyzstan',
    dial: '+996',
    groups: [3, 3, 3],
    hint: '700 123 456',
  ),
  _Country(
    flag: '🇹🇯',
    short: 'Tjk',
    nameUz: 'Tojikiston',
    nameRu: 'Таджикистан',
    nameEn: 'Tajikistan',
    dial: '+992',
    groups: [2, 3, 2, 2],
    hint: '90 123 45 67',
  ),
  _Country(
    flag: '🌐',
    short: 'Other',
    nameUz: 'Boshqa davlat',
    nameRu: 'Другая страна',
    nameEn: 'Other country',
    dial: '+',
    groups: [3, 3, 3, 3, 3],
    hint: '1 202 555 0123',
    minDigits: 10,
  ),
];

/// Phone number entry — sends an (mock) SMS code. The number is required:
/// the button stays disabled until all digits for the selected country are
/// entered.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, this.isMaster = false});

  /// When true this is the master sign-in flow — only the header title and
  /// the post-verify destination differ from the client flow.
  final bool isMaster;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  final _clientAuth = ClientAuthService();
  final _masterService = MasterService();

  _Country _country = _countries.first;

  bool _loading = false;

  /// Backend/network error shown inline under the phone field (e.g.
  /// "Данный номер телефона уже зарегистрирован."). Cleared on edit.
  String? _error;

  /// Rate-limit (429) lockout: seconds until requesting a code is allowed
  /// again. While > 0 the button is disabled and a live countdown message
  /// is shown instead of [_error].
  int _blockSeconds = 0;
  Timer? _blockTimer;

  @override
  void dispose() {
    _blockTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Starts the live 429 lockout countdown (turns the raw backend
  /// "try again in 354s" text into a readable, ticking message).
  void _startBlock(int seconds) {
    _blockTimer?.cancel();
    setState(() {
      _blockSeconds = seconds;
      _error = null;
    });
    _blockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_blockSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _blockSeconds = 0);
      } else {
        if (mounted) setState(() => _blockSeconds--);
      }
    });
  }

  int get _digitCount => _controller.text.replaceAll(RegExp(r'\D'), '').length;
  bool get _isValid =>
      _digitCount >= _country.requiredDigits && _digitCount <= _country.digits;

  /// Full international phone, e.g. `+998901234567`.
  String get _phone =>
      '${_country.dial}${_controller.text.replaceAll(RegExp(r'\D'), '')}';

  /// Bottom sheet listing the selectable countries.
  Future<void> _pickCountry() async {
    final lang = LocaleController.language.value;
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                tr(
                  lang,
                  'Davlatni tanlang',
                  'Выберите страну',
                  'Select a country',
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            for (final c in _countries)
              ListTile(
                onTap: () => Navigator.of(ctx).pop(c),
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(
                  tr(lang, c.nameUz, c.nameRu, c.nameEn),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                trailing: Text(
                  c.dial,
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      _controller.clear();
      _error = null;
    });
  }

  /// Requests an SMS code for the entered number, then opens the OTP screen.
  Future<void> _sendCode() async {
    if (!_isValid || _loading || _blockSeconds > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final lang = LocaleController.language.value;
    try {
      final phone = _phone;
      final expiresIn = widget.isMaster
          ? await _masterService.sendOtp(phone)
          : await _clientAuth.sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: phone,
            isMaster: widget.isMaster,
            resendSeconds: expiresIn >= 60 ? 60 : expiresIn,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final wait = e.isRateLimited ? e.retryAfterSeconds : null;
      if (wait != null) {
        _startBlock(wait);
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    // Rate-limit lockout beats a plain error: it ticks down live.
    final errorText = _blockSeconds > 0
        ? tr(
            lang,
            'Soʻrovlar juda koʻp — ${formatWait(lang, _blockSeconds)} dan '
                'soʻng qayta urinib koʻring',
            'Слишком много запросов — повторите через '
                '${formatWait(lang, _blockSeconds)}',
            'Too many requests — try again in '
                '${formatWait(lang, _blockSeconds)}',
          )
        : _error;
    return BrandedScaffold(
      title: widget.isMaster
          ? tr(lang, 'Usta uchun kirish', 'Вход для мастера', 'Master sign in')
          : tr(lang, 'Kirish', 'Вход', 'Sign in'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              tr(
                lang,
                'Telefon raqamingizni kiriting',
                'Введите номер телефона',
                'Enter your phone number',
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                lang,
                'Tasdiqlash kodi bilan SMS yuboramiz',
                'Отправим SMS с кодом подтверждения',
                'We will send an SMS with a code',
              ),
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            Text(
              tr(lang, 'Telefon raqami', 'Номер телефона', 'Phone number'),
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _CountrySelector(country: _country, onTap: _pickCountry),
                const SizedBox(width: 8),
                Expanded(
                  child: _PhoneField(
                    controller: _controller,
                    country: _country,
                    hasError: errorText != null,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              tr(
                lang,
                'Davom etish orqali siz FixLeo foydalanish shartlari va '
                    'maxfiylik siyosatiga rozilik bildirasiz',
                'Продолжая, вы соглашаетесь с условиями использования и '
                    'политикой конфиденциальности FixLeo',
                'By continuing you agree to FixLeo terms of use and '
                    'privacy policy',
              ),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: _loading
                  ? tr(lang, 'Yuborilmoqda...', 'Отправка...', 'Sending...')
                  : tr(lang, 'Kod olish', 'Получить код', 'Get code'),
              onPressed: _isValid && !_loading && _blockSeconds == 0
                  ? _sendCode
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a local number by the country's digit groups while typing,
/// e.g. [2, 3, 2, 2] → "90 123 45 67".
class _PhoneNumberFormatter extends TextInputFormatter {
  const _PhoneNumberFormatter(this._groups);

  final List<int> _groups;

  int get _maxDigits => _groups.fold(0, (a, b) => a + b);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);

    final buffer = StringBuffer();
    var index = 0;
    for (var g = 0; g < _groups.length && index < digits.length; g++) {
      if (g != 0) buffer.write(' ');
      final end = (index + _groups[g]).clamp(0, digits.length);
      buffer.write(digits.substring(index, end));
      index = end;
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// White rounded pill with the selected country's flag and short name —
/// opens the country picker (matches the Figma "Uzb" selector).
class _CountrySelector extends StatelessWidget {
  const _CountrySelector({required this.country, required this.onTap});

  final _Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
            Text(
              country.short,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onChanged,
    this.hasError = false,
  });

  final TextEditingController controller;
  final _Country country;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasError
            ? Border.all(color: AppColors.danger, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Text(
            country.dial,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.black12),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneNumberFormatter(country.groups)],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: country.hint,
                hintStyle: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
