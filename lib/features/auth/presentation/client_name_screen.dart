import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';

/// Final step for brand-new clients — the "Registratsiya" form from the
/// design: full name + city. Completes registration
/// (`POST /clients/auth/register`) and signs the user in. Reached only when
/// `verify-otp` returned `isRegistered: false`.
///
/// Note: the register API only accepts `name` — the city is collected to
/// match the design but not yet sent anywhere.
class ClientNameScreen extends StatefulWidget {
  const ClientNameScreen({super.key, required this.phone, required this.code});

  final String phone;
  final String code;

  @override
  State<ClientNameScreen> createState() => _ClientNameScreenState();
}

class _ClientNameScreenState extends State<ClientNameScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _service = ClientAuthService();

  bool _loading = false;

  /// Backend/network error shown inline under the form. Cleared on edit.
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _name.text.trim().length >= 3 && _city.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final lang = LocaleController.language.value;
    try {
      await _service.register(
        phone: widget.phone,
        code: widget.code,
        name: _name.text.trim(),
      );
      if (!mounted) return;
      // Registration done — pick a location first, then the home screen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AddressScreen(isOnboarding: true),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.errorFor('name') ?? e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = tr(lang, 'Xatolik yuz berdi',
          'Произошла ошибка', 'Something went wrong'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Roʻyxatdan oʻtish', 'Регистрация', 'Registration'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              tr(lang, 'Oʻzingiz haqingizda', 'Расскажите о себе',
                  'Tell us about yourself'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: tr(lang, 'Ism va familiya', 'Имя и фамилия', 'Full name'),
              controller: _name,
              hint: tr(lang, 'Aleksey Ivanov', 'Алексей Иванов',
                  'Alexey Ivanov'),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: tr(lang, 'Shahar', 'Город', 'City'),
              controller: _city,
              hint: tr(lang, 'Toshkent', 'Ташкент', 'Tashkent'),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.danger,
                ),
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: _loading
                  ? tr(lang, 'Kuting...', 'Подождите...', 'Please wait...')
                  : tr(lang, 'Keyingi', 'Далее', 'Next'),
              onPressed: _isValid && !_loading ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gray label above a rounded white text field (same style as the master
/// onboarding form).
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
