import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';

/// Explains why a permission is useful before Android/iOS displays its terse
/// system dialog. The system prompt is shown only after the user continues.
Future<bool> showPermissionRationale(
  BuildContext context, {
  required IconData icon,
  required String titleUz,
  required String titleRu,
  required String titleEn,
  required String messageUz,
  required String messageRu,
  required String messageEn,
}) async {
  final lang = LocaleController.language.value;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => GlassAlertDialog(
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF4FE),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.blue, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(tr(lang, titleUz, titleRu, titleEn))),
            ],
          ),
          content: Text(
            tr(lang, messageUz, messageRu, messageEn),
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr(lang, 'Hozir emas', 'Не сейчас', 'Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr(lang, 'Davom etish', 'Продолжить', 'Continue')),
            ),
          ],
        ),
      ) ??
      false;
}
