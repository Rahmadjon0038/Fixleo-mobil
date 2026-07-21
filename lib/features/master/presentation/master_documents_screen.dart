import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_document_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_selfie_screen.dart';

class _Doc {
  _Doc(this.nameUz, this.nameRu, this.nameEn, this.icon, this.type);
  final String nameUz;
  final String nameRu;
  final String nameEn;
  final IconData icon;
  final MasterDocumentType type;
  bool uploaded = false;
  bool uploading = false;

  String name(AppLanguage lang) => tr(lang, nameUz, nameRu, nameEn);
}

/// Master onboarding — upload verification documents. Uploaded items show a
/// blue "Yuklandi" status; pending ones get a dashed outline and open the
/// gallery on tap.
class MasterDocumentsScreen extends StatefulWidget {
  const MasterDocumentsScreen({super.key});

  @override
  State<MasterDocumentsScreen> createState() => _MasterDocumentsScreenState();
}

class _MasterDocumentsScreenState extends State<MasterDocumentsScreen> {
  final _picker = ImagePicker();
  final _service = MasterService();

  final _docs = [
    _Doc('Pasport — old tomoni', 'Паспорт — лицевая сторона', 'Passport - front side',
        Icons.verified_outlined,
        MasterDocumentType.passportFront),
    _Doc('Pasport — orqa tomoni', 'Паспорт — оборотная сторона', 'Passport - back side',
        Icons.photo_camera_outlined,
        MasterDocumentType.passportBack),
  ];

  bool get _allRequiredUploaded => _docs.every((d) => d.uploaded);

  /// Picks an image and uploads it as that document type
  /// (`POST /masters/me/documents`). Re-uploading replaces the previous file.
  Future<void> _upload(_Doc doc) async {
    if (doc.uploading) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => doc.uploading = true);
    try {
      await _service.uploadDocument(type: doc.type, filePath: file.path);
      if (!mounted) return;
      setState(() {
        doc.uploaded = true;
        doc.uploading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => doc.uploading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => doc.uploading = false);
      final lang = LocaleController.language.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Hujjatlar', 'Документы', 'Documents'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _docs.length; i++) ...[
              if (i != 0) const SizedBox(height: 10),
              _DocRow(doc: _docs[i], onTap: () => _upload(_docs[i])),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                tr(
                  lang,
                  'Tekshiruv 24 soat davom etadi.',
                  'Проверка занимает 24 часа.',
                  'Verification takes 24 hours.',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: AppColors.blue,
                ),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
              onPressed: _allRequiredUploaded
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MasterSelfieScreen(),
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

/// One document row — solid white when uploaded, dashed blue outline when
/// still pending.
class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});

  final _Doc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final row = Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(doc.icon, size: 20, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name(lang),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doc.uploading
                      ? tr(lang, 'Yuklanmoqda...', 'Загружается...', 'Uploading...')
                      : doc.uploaded
                          ? tr(lang, 'Yuklandi', 'Загружено', 'Uploaded')
                          : tr(lang, 'Yuklash uchun bosing', 'Нажмите, чтобы загрузить', 'Tap to upload'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    color: doc.uploaded
                        ? AppColors.blue
                        : const Color(0xFF9494A3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (doc.uploaded) return row;

    // Pending: dashed blue outline, tappable to upload.
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.blue, radius: 16),
        child: row,
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border around the child.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, this.radius = 16});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
