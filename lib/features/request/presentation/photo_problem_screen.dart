import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';

/// Step 2 of the "new request" flow — attach up to 6 photos of the problem
/// from the device gallery.
class PhotoProblemScreen extends StatefulWidget {
  const PhotoProblemScreen({super.key});

  @override
  State<PhotoProblemScreen> createState() => _PhotoProblemScreenState();
}

class _PhotoProblemScreenState extends State<PhotoProblemScreen> {
  static const _maxPhotos = 6;
  final _picker = ImagePicker();
  final List<XFile?> _photos = List.filled(_maxPhotos, null);

  int get _firstEmpty => _photos.indexWhere((p) => p == null);

  Future<void> _pick(int index) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _photos[index] = file);
  }

  void _remove(int index) => setState(() => _photos[index] = null);

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Muammo rasmi',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '6 tagacha rasm qoʻshing — ustaga vazifani baholash osonroq boʻladi',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: AppColors.navy.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var r = 0; r < 2; r++) ...[
                    if (r != 0) const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var c = 0; c < 3; c++) ...[
                          if (c != 0) const SizedBox(width: 12),
                          Expanded(
                            child: _PhotoSlot(
                              file: _photos[r * 3 + c],
                              active: r * 3 + c == _firstEmpty,
                              onTap: () => _pick(r * 3 + c),
                              onRemove: () => _remove(r * 3 + c),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Keyingi',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddressScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.file,
    required this.active,
    required this.onTap,
    required this.onRemove,
  });

  final XFile? file;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: file != null ? _filled(context) : _empty(),
    );
  }

  Widget _filled(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(file!.path), fit: BoxFit.cover),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    final borderColor = active
        ? AppColors.blue
        : AppColors.navy.withValues(alpha: 0.20);
    final iconColor = active
        ? AppColors.blue
        : AppColors.navy.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: borderColor, radius: 16),
        child: Container(
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAF4FE) : const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.photo_camera_outlined, color: iconColor, size: 26),
        ),
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
