import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';

/// Settings — the personal-data form from the design: first/last name, the
/// verified phone number (read-only, changed via support), gender and birth
/// date. Opened from the profile "Sozlamalar" row.
///
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Gender { male, female }

class _SettingsScreenState extends State<SettingsScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _service = ClientAuthService();

  String _phone = '';
  _Gender? _gender;
  DateTime? _birthday;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = await _service.me();
      if (!mounted) return;
      setState(() {
        final parts = (client.name ?? '').trim().split(RegExp(r'\s+'));
        _first.text = parts.isNotEmpty ? parts.first : '';
        _last.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _phone = client.phone;
        _gender = switch (client.gender) {
          'male' => _Gender.male,
          'female' => _Gender.female,
          _ => null,
        };
        _birthday = client.birthDate;
      });
    } catch (_) {
      // Leave the form empty if the profile can't be fetched.
    }
  }

  /// "+998 90 123 45 67" for display (falls back to the raw value).
  String get _prettyPhone {
    final d = _phone.replaceAll(RegExp(r'\D'), '');
    if (!_phone.startsWith('+998') || d.length != 12) return _phone;
    final local = d.substring(3);
    return '+998 ${local.substring(0, 2)} ${local.substring(2, 5)} '
        '${local.substring(5, 7)} ${local.substring(7, 9)}';
  }

  bool get _isValid =>
      '${_first.text.trim()} ${_last.text.trim()}'.trim().length >= 3;

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final lang = LocaleController.language.value;
    try {
      final name = '${_first.text.trim()} ${_last.text.trim()}'.trim();
      await _service.updateProfile(
        name: name,
        birthDate: _birthday,
        gender: _gender?.name,
      );
      await CurrentUser.instance.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(tr(lang, 'Saqlandi', 'Сохранено', 'Saved'))),
        );
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            e.errorFor('name') ??
            e.errorFor('birthDate') ??
            e.errorFor('gender') ??
            e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickGender() async {
    final lang = LocaleController.language.value;
    final picked = await showGlassModalBottomSheet<_Gender>(
      context: context,
      topRadius: 24,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              onTap: () => Navigator.of(ctx).pop(_Gender.male),
              leading: const Icon(Icons.male, color: AppColors.navy),
              title: Text(tr(lang, 'Erkak', 'Мужской', 'Male')),
            ),
            ListTile(
              onTap: () => Navigator.of(ctx).pop(_Gender.female),
              leading: const Icon(Icons.female, color: AppColors.navy),
              title: Text(tr(lang, 'Ayol', 'Женский', 'Female')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _gender = picked);
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _birthday = picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Sozlamalar', 'Настройки', 'Settings'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(tr(lang, 'Ism', 'Имя', 'First name')),
                    _textField(
                      controller: _first,
                      hint: tr(lang, 'Anton', 'Антон', 'Anton'),
                    ),
                    const SizedBox(height: 14),
                    _label(tr(lang, 'Familiya', 'Фамилия', 'Last name')),
                    _textField(
                      controller: _last,
                      hint: tr(lang, 'Batonov', 'Батонов', 'Batonov'),
                    ),
                    const SizedBox(height: 14),
                    _label(
                      tr(
                        lang,
                        'Telefon raqami',
                        'Номер телефона',
                        'Phone number',
                      ),
                    ),
                    _staticField(
                      child: Text(
                        _prettyPhone.isEmpty ? '—' : _prettyPhone,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 18,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr(
                            lang,
                            'Raqam tasdiqlangan',
                            'Номер подтвержден',
                            'Number verified',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _label(tr(lang, 'Jins', 'Пол', 'Gender')),
                    GestureDetector(
                      onTap: _pickGender,
                      child: _staticField(
                        child: Row(
                          children: [
                            Icon(
                              _gender == _Gender.female
                                  ? Icons.female
                                  : Icons.male,
                              size: 20,
                              color: _gender == null
                                  ? AppColors.muted
                                  : AppColors.navy,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _gender == null
                                  ? tr(lang, 'Tanlang', 'Выберите', 'Select')
                                  : _gender == _Gender.male
                                  ? tr(lang, 'Erkak', 'Мужской', 'Male')
                                  : tr(lang, 'Ayol', 'Женский', 'Female'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _gender == null
                                    ? AppColors.muted
                                    : AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label(
                      tr(
                        lang,
                        'Tugʻilgan kun*',
                        'День рождения*',
                        'Birth date*',
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: _staticField(
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                              color: _birthday == null
                                  ? AppColors.muted
                                  : AppColors.navy,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _birthday == null
                                  ? tr(lang, 'Tanlang', 'Выберите', 'Select')
                                  : _fmtDate(_birthday!),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _birthday == null
                                    ? AppColors.muted
                                    : AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            Center(
              child: Text.rich(
                TextSpan(
                  text: tr(
                    lang,
                    'Raqamni almashtirish kerakmi? ',
                    'Нужна смена номера? ',
                    'Need to change the number? ',
                  ),
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                  children: [
                    TextSpan(
                      text: tr(
                        lang,
                        'Qoʻllab-quvvatlashga yozing.',
                        'Напишите в поддержку.',
                        'Contact support.',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _saving
                  ? tr(lang, 'Saqlanmoqda...', 'Сохранение...', 'Saving...')
                  : tr(
                      lang,
                      'Oʻzgarishlarni saqlash',
                      'Сохранить изменения',
                      'Save changes',
                    ),
              onPressed: _isValid && !_saving ? _save : null,
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
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
  }) {
    // GlassTextField doesn't expose textCapitalization, so a raw TextField is
    // kept for that behavior while still living inside the glass panel.
    return GlassContainer(
      height: 48,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() => _error = null),
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
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
    );
  }

  /// Frosted glass pill used for the read-only phone and the tappable
  /// pickers.
  Widget _staticField({required Widget child}) {
    return GlassContainer(
      height: 48,
      width: double.infinity,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
