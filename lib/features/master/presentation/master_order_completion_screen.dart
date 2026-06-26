import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// Master's "finish the job" screen — order summary, up to six "done work"
/// photos and a button to mark the order completed. The client then confirms
/// on their side.
class MasterOrderCompletionScreen extends StatelessWidget {
  const MasterOrderCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Buyurtmani yakunlash',
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: const [
                // Order summary card.
                _SummaryCard(),
                SizedBox(height: 10),
                // Photos of the completed work.
                _PhotosCard(),
                SizedBox(height: 10),
                // Info banner.
                _InfoBanner(
                  'Mijoz oʻz tomonidan bajarilishini tasdiqlaydi.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: PrimaryButton(
              label: 'Bajarildi deb belgilash',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// White card with service / time / price summary rows.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: const [
          _SummaryRow(label: 'Xizmat', value: 'Smesitel almashtirish'),
          SizedBox(height: 8),
          _SummaryRow(label: 'Vaqt', value: 'Bugun, 12:00–15:00'),
          SizedBox(height: 8),
          _SummaryRow(label: 'Master taklifi', value: '50 000 soʻm'),
        ],
      ),
    );
  }
}

/// One "label … value" row: gray label on the left, navy value on the right.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.16,
            color: Color(0xFF8D96A4),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.16,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

/// White card with the hint text and a 3×2 photo grid (first cell adds photos).
class _PhotosCard extends StatelessWidget {
  const _PhotosCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bajarilgan ishdan 6 tagacha foto qoʻshing — mijozga koʻrsatish '
            'uchun',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 105 / 108,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const _AddPhotoTile(),
              for (var i = 0; i < 5; i++) _PhotoCell(index: i),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dashed "add photo" tile shown first in the grid.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.blue,
        radius: 16,
        dash: 6,
        gap: 4,
        strokeWidth: 1.5,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Icon(
            Icons.photo_camera_outlined,
            size: 24,
            color: AppColors.blue,
          ),
        ),
      ),
    );
  }
}

/// One filled photo cell (placeholder image, rounded).
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        'https://picsum.photos/seed/fixleojob$index/200',
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const ColoredBox(color: Color(0xFFE2E8F0)),
        errorBuilder: (context, error, stack) =>
            const ColoredBox(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}

/// Light-blue rounded info banner.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border around its child.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      dash != oldDelegate.dash ||
      gap != oldDelegate.gap ||
      strokeWidth != oldDelegate.strokeWidth;
}
