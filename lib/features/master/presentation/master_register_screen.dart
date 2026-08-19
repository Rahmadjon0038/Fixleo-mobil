import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_profile_screen.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';

/// First master onboarding step — basic details (name, city, experience).
/// The "Davom etish" button stays disabled until all three are filled.
class MasterRegisterScreen extends StatefulWidget {
  const MasterRegisterScreen({
    super.key,
    this.initialName,
    this.initialCity,
    this.initialExperienceYears,
  });

  final String? initialName;
  final String? initialCity;
  final int? initialExperienceYears;

  @override
  State<MasterRegisterScreen> createState() => _MasterRegisterScreenState();
}

class _MasterRegisterScreenState extends State<MasterRegisterScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _experience;
  final _service = MasterService();

  bool _loading = false;

  /// Backend/network error shown inline under the form. Cleared on edit.
  String? _error;
  String? _nameError;
  String? _cityError;
  String? _experienceError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _city = TextEditingController(text: widget.initialCity ?? '');
    _experience = TextEditingController(
      text: widget.initialExperienceYears?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _experience.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _name.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _experience.text.trim().isNotEmpty;

  void _clearFieldErrors() {
    _nameError = null;
    _cityError = null;
    _experienceError = null;
  }

  void _applyValidationErrors(ApiException e) {
    _nameError = e.errorFor('name');
    _cityError = e.errorFor('city');
    _experienceError =
        e.errorFor('experienceYears') ?? e.errorFor('experience');

    // If the backend returns a generic validation message without field
    // details, keep it visible above the form.
    final hasFieldErrors =
        _nameError != null || _cityError != null || _experienceError != null;
    _error = hasFieldErrors ? null : e.message;
  }

  /// Signs out of the unfinished master account and restarts onboarding —
  /// this screen is the flow's root, so it's the only way out of it.
  Future<void> _logout() async {
    if (_loading) return;
    await _service.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (route) => false,
    );
  }

  /// Saves the basic profile (`PATCH /masters/me/profile`) then moves on.
  Future<void> _saveAndContinue() async {
    if (!_isValid || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _clearFieldErrors();
    });
    try {
      await _service.updateProfile(
        name: _name.text.trim(),
        city: _city.text.trim(),
        experienceYears: int.tryParse(_experience.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MasterProfileScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _applyValidationErrors(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr(
          LocaleController.language.value,
          'Tarmoq xatosi',
          'Ошибка сети',
          'Network error',
        );
      });
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(lang, 'Oʻzingiz haqingizda', 'Расскажите о себе', 'About you'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: tr(lang, 'Ism va familiya', 'Имя и фамилия', 'Full name'),
              controller: _name,
              hint: tr(
                lang,
                'Aleksey Ivanov',
                'Алексей Иванов',
                'Aleksey Ivanov',
              ),
              textCapitalization: TextCapitalization.words,
              errorText: _nameError,
              onChanged: (_) => setState(() {
                _error = null;
                _nameError = null;
              }),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: tr(lang, 'Shahar', 'Город', 'City'),
              controller: _city,
              hint: tr(lang, 'Shahar nomi', 'Название города', 'City name'),
              textCapitalization: TextCapitalization.words,
              errorText: _cityError,
              onChanged: (_) => setState(() {
                _error = null;
                _cityError = null;
              }),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: tr(
                lang,
                'Ish tajribasi, yil',
                'Опыт работы, лет',
                'Work experience, years',
              ),
              controller: _experience,
              hint: '5',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: _experienceError,
              onChanged: (_) => setState(() {
                _error = null;
                _experienceError = null;
              }),
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
                  ? tr(lang, 'Saqlanmoqda...', 'Сохранение...', 'Saving...')
                  : tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
              onPressed: _isValid && !_loading ? _saveAndContinue : null,
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _logout,
                child: Text(
                  tr(
                    LocaleController.language.value,
                    'Akkauntdan chiqish',
                    'Выйти из аккаунта',
                    'Sign out',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.danger,
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

/// Gray label above a rounded white text field, matching the master
/// onboarding form style.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: 4),
        GlassTextField(
          height: 52,
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          hintText: hint,
          hasError: errorText != null,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}
