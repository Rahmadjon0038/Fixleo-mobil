import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';

/// Functional Telegram-style attachment chooser. The system picker handles
/// permissions and the real gallery/camera UI; the chat uploads selected files.
Future<ImageSource?> showAttachPhotosSheet(BuildContext context) {
  final lang = LocaleController.language.value;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x55000000),
    builder: (sheetContext) => SafeArea(
      child: GlassContainer(
        margin: const EdgeInsets.all(10),
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD3D7DE),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(lang, 'Rasm yuborish', 'Отправить фото', 'Send a photo'),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _AttachmentAction(
              icon: Icons.photo_library_outlined,
              iconColor: AppColors.blue,
              title: tr(lang, 'Galereya', 'Галерея', 'Gallery'),
              subtitle: tr(
                lang,
                'Bir nechta rasm tanlash mumkin',
                'Можно выбрать несколько фото',
                'Select multiple photos',
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
            _AttachmentAction(
              icon: Icons.photo_camera_outlined,
              iconColor: const Color(0xFF16A06A),
              title: tr(lang, 'Kamera', 'Камера', 'Camera'),
              subtitle: tr(
                lang,
                'Hozir suratga olish',
                'Сделать фото сейчас',
                'Take a photo now',
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      // Nested inside an already-blurred sheet — .lite avoids stacking
      // another BackdropFilter.
      child: GlassContainer.lite(
        tint: const Color(0xFFF5F7FA),
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF8D96A4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFA3ADBA)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
