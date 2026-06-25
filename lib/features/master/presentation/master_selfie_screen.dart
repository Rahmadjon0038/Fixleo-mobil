import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
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
  XFile? _selfie;

  /// Try to capture a selfie from the front camera, then continue. Camera
  /// may be unavailable on some platforms — proceed regardless.
  Future<void> _takeSelfie() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );
      if (file == null) return; // user canceled
      setState(() => _selfie = file);
      _goNext();
    } on Exception {
      _goNext();
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MasterVerificationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Pasport bilan selfi',
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
                          _rules[i],
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
            // For now the button just advances to the verification screen
            // (camera capture still works by tapping the circle above).
            PrimaryButton(label: 'Selfi olish', onPressed: _goNext),
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
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ));

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
