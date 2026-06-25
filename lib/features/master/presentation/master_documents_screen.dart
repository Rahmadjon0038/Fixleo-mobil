import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_selfie_screen.dart';

class _Doc {
  _Doc(this.name, this.icon, {required this.uploaded});
  final String name;
  final IconData icon;
  bool uploaded;
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

  final _docs = [
    _Doc('oneID', Icons.badge_outlined, uploaded: true),
    _Doc('Pasport — old tomoni', Icons.verified_outlined, uploaded: true),
    _Doc('Pasport — orqa tomoni', Icons.photo_camera_outlined,
        uploaded: false),
  ];

  Future<void> _upload(_Doc doc) async {
    if (doc.uploaded) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => doc.uploaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Hujjatlar',
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
              child: const Text(
                'Tekshiruv 24 soat davom etadi.',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: AppColors.blue,
                ),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Davom etish',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MasterSelfieScreen(),
                  ),
                );
              },
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
                  doc.name,
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
                  doc.uploaded ? 'Yuklandi' : 'Yuklash uchun bosing',
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
