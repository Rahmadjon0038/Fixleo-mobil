import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';

/// Shows the shared destructive-action warning used by both account roles.
Future<bool> showAccountDeleteConfirmation({
  required BuildContext context,
  required AppLanguage language,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => GlassAlertDialog(
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiquidSurface(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_outlined,
              size: 32,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              language,
              'Akkauntni oʻchirasizmi?',
              'Удалить аккаунт?',
              'Delete your account?',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              height: 26 / 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              language,
              'Diqqat! Barcha maʼlumotlaringiz butunlay oʻchib ketadi. Davom etishga rozimisiz?',
              'Внимание! Все ваши данные будут безвозвратно удалены. Вы уверены, что хотите продолжить?',
              'Warning! All your data will be permanently deleted. Are you sure you want to continue?',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: LiquidActionButton.outlined(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(tr(language, 'Bekor qilish', 'Отмена', 'Cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiquidActionButton.filled(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr(language, 'Ha, oʻchirish', 'Да, удалить', 'Yes, delete'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  return confirmed == true;
}
