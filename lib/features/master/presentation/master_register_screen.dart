import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
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
    });
    try {
      await _service.updateProfile(
        name: _name.text.trim(),
        city: _city.text.trim(),
        experienceYears: int.tryParse(_experience.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MasterProfileScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Tarmoq xatosi');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Roʻyxatdan oʻtish',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Oʻzingiz haqingizda',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Ism va familiya',
              controller: _name,
              hint: 'Aleksey Ivanov',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Shahar',
              controller: _city,
              hint: 'Toshkent',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Ish tajribasi, yil',
              controller: _experience,
              hint: '5',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              label: _loading ? 'Saqlanmoqda...' : 'Davom etish',
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
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

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
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
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
