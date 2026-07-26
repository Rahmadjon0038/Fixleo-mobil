import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_document_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_verification_screen.dart';

/// Master onboarding — selfie-with-passport verification. Tapping the circle
/// or the button opens the camera; once a shot is taken, onboarding finishes.
class MasterSelfieScreen extends StatefulWidget {
  const MasterSelfieScreen({super.key});

  @override
  State<MasterSelfieScreen> createState() => _MasterSelfieScreenState();
}

class _MasterSelfieScreenState extends State<MasterSelfieScreen> {
  static const _rules = [
    'Yuz toʻliq kadrda',
    'Pasport ochiq holatda',
    'Yaxshi yoritilgan',
  ];

  final _picker = ImagePicker();
  final _service = MasterService();
  XFile? _selfie;
  bool _uploading = false;

  /// TEMP (dev only): on desktop there is no camera flow, so the screen
  /// auto-advances after 3 seconds to let onboarding be clicked through
  /// (e.g. when running on macOS). Phones keep the real selfie flow.
  Timer? _autoSkip;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid && !Platform.isIOS) {
      _autoSkip = Timer(const Duration(seconds: 3), _goNext);
    }
  }

  @override
  void dispose() {
    _autoSkip?.cancel();
    super.dispose();
  }

  /// Captures a selfie, uploads it as `selfie_with_passport`
  /// (`POST /masters/me/documents`), then advances to the verification screen.
  Future<void> _takeSelfie() async {
    if (_uploading) return;
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );
    } on Exception {
      // Camera unavailable (e.g. desktop) — fall back to the gallery.
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    }
    if (file == null) return; // user canceled
    setState(() {
      _selfie = file;
      _uploading = true;
    });
    try {
      await _service.uploadDocument(
        type: MasterDocumentType.selfieWithPassport,
        filePath: file.path,
      );
      _goNext();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
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

  void _goNext() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MasterVerificationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Pasport bilan selfi',
        'Селфи с паспортом',
        'Selfie with passport',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _takeSelfie,
                child: CustomPaint(
                  painter: _DashedCirclePainter(color: AppColors.blue),
                  child: Container(
                    width: 240,
                    height: 240,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selfie != null
                        ? Image.file(File(_selfie!.path), fit: BoxFit.cover)
                        : const Icon(
                            Icons.photo_camera_outlined,
                            size: 48,
                            color: AppColors.blue,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _rules.length; i++) ...[
                    if (i != 0) const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr(
                            lang,
                            _rules[i],
                            i == 0
                                ? 'Лицо в кадре целиком'
                                : i == 1
                                ? 'Паспорт открыт'
                                : 'Хорошее освещение',
                            i == 0
                                ? 'Face fully in frame'
                                : i == 1
                                ? 'Passport open'
                                : 'Good lighting',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            letterSpacing: -0.16,
                            color: Color(0xFF8D96A4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: _uploading
                  ? tr(lang, 'Yuklanmoqda...', 'Загружается...', 'Uploading...')
                  : tr(lang, 'Selfi olish', 'Сделать селфи', 'Take selfie'),
              onPressed: _uploading ? null : _takeSelfie,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a dashed circle the size of its child.
class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  static const _dash = 7.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2,
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
