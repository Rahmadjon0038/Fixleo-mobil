import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_profile_screen.dart';

/// First master onboarding step — basic details (name, city, experience).
/// The "Davom etish" button stays disabled until all three are filled.
class MasterRegisterScreen extends StatefulWidget {
  const MasterRegisterScreen({super.key});

  @override
  State<MasterRegisterScreen> createState() => _MasterRegisterScreenState();
}

class _MasterRegisterScreenState extends State<MasterRegisterScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _experience = TextEditingController();

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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Shahar',
              controller: _city,
              hint: 'Toshkent',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Ish tajribasi, yil',
              controller: _experience,
              hint: '5',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Davom etish',
              onPressed: _isValid
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MasterProfileScreen(),
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
