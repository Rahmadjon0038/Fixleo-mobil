import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/realtime/master_realtime_service.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_verified_screen.dart';
import 'package:fixleo/features/master/presentation/master_verification_rejected_screen.dart';

/// Verification status — shown after the selfie step. On entry it submits the
/// application (`POST /masters/me/verification/submit`) and then waits for the
/// moderator's decision, which arrives live over WebSocket
/// (`verification:update`). Approved → success screen; rejected → reason shown.
class MasterVerificationScreen extends StatefulWidget {
  const MasterVerificationScreen({super.key, this.submitOnOpen = true});

  /// False when the backend already reports `pending`; the screen then only
  /// waits for the moderator event instead of re-submitting the same KYC.
  final bool submitOnOpen;

  @override
  State<MasterVerificationScreen> createState() =>
      _MasterVerificationScreenState();
}

class _MasterVerificationScreenState extends State<MasterVerificationScreen> {
  final _service = MasterService();
  final _realtime = MasterRealtimeService();

  bool _decided = false;

  @override
  void initState() {
    super.initState();
    if (widget.submitOnOpen) {
      _submit();
    }
    _listenForDecision();
  }

  /// Submits the KYC application. If it was already submitted (409/400) we just
  /// keep waiting for the decision.
  Future<void> _submit() async {
    try {
      await _service.submitVerification();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppFeedback.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // Network hiccup — the moderator decision still arrives via WS / re-login.
    }
  }

  void _listenForDecision() {
    _realtime.connect(
      onUpdate: (update) {
        if (_decided || !mounted) return;
        _decided = true;
        if (update.isApproved) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MasterVerifiedScreen()),
          );
        } else if (update.isRejected) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MasterVerificationRejectedScreen(
                rejectionReason: update.rejectionReason,
                rejectionReasons: update.rejectionReasons,
              ),
            ),
          );
        }
      },
      onForcedLogout: (_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  @override
  void dispose() {
    _realtime.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Tekshiruv', 'Проверка', 'Verification'),
      showBack: false,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            // Header card — animated-looking clock + status text.
            GlassCard(
              radius: 30,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  LiquidSurface(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.history,
                      size: 34,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr(
                      lang,
                      'Hujjatlar tekshiruvda',
                      'Документы на проверке',
                      'Documents under review',
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    tr(
                      lang,
                      'Odatda 24 soat davom etadi',
                      'Обычно занимает 24 часа',
                      'Usually takes 24 hours',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Status checklist.
            GlassCard(
              radius: 20,
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _StatusRow(
                    icon: Icons.verified,
                    label: tr(
                      lang,
                      'Pasport yuklandi',
                      'Паспорт загружен',
                      'Passport uploaded',
                    ),
                    done: true,
                  ),
                  _StatusRow(
                    icon: Icons.verified,
                    label: tr(
                      lang,
                      'Selfi yuklandi',
                      'Селфи загружено',
                      'Selfie uploaded',
                    ),
                    done: true,
                  ),
                  _StatusRow(
                    icon: Icons.schedule,
                    label: tr(
                      lang,
                      'Moderator qarori',
                      'Решение модератора',
                      'Moderator decision',
                    ),
                    done: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One verification step — blue check when done, gray clock when pending.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.done,
  });

  final IconData icon;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.blue : const Color(0xFF8D96A4);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w500,
              color: done ? AppColors.navy : const Color(0xFF8D96A4),
            ),
          ),
        ],
      ),
    );
  }
}
