import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/localized_rejection_reasons.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_register_screen.dart';

/// Dedicated moderator rejection state for master onboarding.
class MasterVerificationRejectedScreen extends StatefulWidget {
  const MasterVerificationRejectedScreen({
    super.key,
    this.rejectionReason,
    this.rejectionReasons = const LocalizedRejectionReasons(),
    this.masterService,
  });

  final String? rejectionReason;
  final LocalizedRejectionReasons rejectionReasons;
  final MasterService? masterService;

  @override
  State<MasterVerificationRejectedScreen> createState() =>
      _MasterVerificationRejectedScreenState();
}

class _MasterVerificationRejectedScreenState
    extends State<MasterVerificationRejectedScreen> {
  static const _red100 = Color(0xFFFEE2E2);
  static const _red400 = Color(0xFFF87171);
  static const _gray = Color(0xFF8D96A4);

  late final MasterService _service = widget.masterService ?? MasterService();
  bool _loading = false;

  String? _reason(AppLanguage language) {
    final reason =
        widget.rejectionReasons.forLanguage(language) ??
        widget.rejectionReason?.trim();
    return reason == null || reason.isEmpty ? null : reason;
  }

  Future<void> _correctDetails() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final master = await _service.me();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MasterRegisterScreen(
            initialName: master.name,
            initialCity: master.city,
            initialExperienceYears: master.experienceYears,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      final language = LocaleController.language.value;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(language, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        language,
        'Tekshiruv natijasi',
        'Результат проверки',
        'Verification result',
      ),
      showBack: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            GlassCard(
              radius: 30,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _red100,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: _red400,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      language,
                      'Tekshiruvdan o‘tmadi',
                      'Проверка не пройдена',
                      'Verification was not passed',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      language,
                      'Maʼlumotlarni tuzatib, arizani qayta yuborishingiz mumkin.',
                      'Исправьте данные и отправьте заявку на проверку повторно.',
                      'Correct the details and submit the application again.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              radius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: _red400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr(
                          language,
                          'Moderator sababi',
                          'Причина модератора',
                          'Moderator reason',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 20 / 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _reason(language) ??
                        tr(
                          language,
                          'Sabab ko‘rsatilmagan. Maʼlumot va hujjatlarni tekshirib qayta yuboring.',
                          'Причина не указана. Проверьте данные и документы перед повторной отправкой.',
                          'No reason was provided. Check the details and documents before resubmitting.',
                        ),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: _gray,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: _loading
                  ? tr(language, 'Yuklanmoqda...', 'Загрузка...', 'Loading...')
                  : tr(
                      language,
                      'Maʼlumotlarni tuzatish',
                      'Исправить данные',
                      'Correct details',
                    ),
              onPressed: _loading ? null : _correctDetails,
            ),
          ],
        ),
      ),
    );
  }
}
