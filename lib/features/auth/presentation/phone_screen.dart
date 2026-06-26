import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/auth/presentation/otp_screen.dart';

/// Phone number entry — sends an (mock) SMS code. The number is required:
/// the button stays disabled until all 9 digits are entered.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _digitCount => _controller.text.replaceAll(RegExp(r'\D'), '').length;
  bool get _isValid => _digitCount == 9;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
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
              tr(lang, 'Telefon raqamingizni kiriting',
                  'Введите номер телефона', 'Enter your phone number'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(lang, 'Tasdiqlash kodi bilan SMS yuboramiz',
                  'Отправим SMS с кодом подтверждения',
                  'We will send an SMS with a code'),
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            Text(
              tr(lang, 'Telefon raqami', 'Номер телефона', 'Phone number'),
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            _PhoneField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
            ),
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
              label: tr(lang, 'Kod olish', 'Получить код', 'Get code'),
              onPressed: _isValid
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OtpScreen(isMaster: widget.isMaster),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a 9-digit Uzbek number as "90 123 45 67" while typing.
class _PhoneNumberFormatter extends TextInputFormatter {
  static const _groups = [2, 3, 2, 2];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);

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

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text(
            '+998',
            style: TextStyle(
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
              inputFormatters: [_PhoneNumberFormatter()],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '90 123 45 67',
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
