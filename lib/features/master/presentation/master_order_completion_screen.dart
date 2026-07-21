import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';

/// Master's "finish the job" screen — order summary + a button to mark the
/// order completed (POST /masters/me/orders/:id/complete). The client then
/// confirms on their side.
class MasterOrderCompletionScreen extends StatefulWidget {
  const MasterOrderCompletionScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<MasterOrderCompletionScreen> createState() =>
      _MasterOrderCompletionScreenState();
}

class _MasterOrderCompletionScreenState extends State<MasterOrderCompletionScreen> {
  final MasterMarketplaceService _market = MasterMarketplaceService();
  bool _busy = false;

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await _market.complete(widget.orderId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MasterHomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Buyurtmani yakunlash', 'Завершение заказа', 'Complete order'),
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _SummaryCard(lang: lang),
                const SizedBox(height: 10),
                _PhotosCard(lang: lang),
                const SizedBox(height: 10),
                _InfoBanner(
                  tr(
                    lang,
                    'Mijoz ish bajarilganini oʻz tomonidan tasdiqlaydi.',
                    'Клиент подтверждает выполнение со своей стороны.',
                    'The client confirms completion on their side.',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: PrimaryButton(
              label: _busy
                  ? '…'
                  : tr(lang, 'Bajarildi deb belgilash', 'Отметить выполненным',
                      'Mark as completed'),
              onPressed: _busy ? null : _complete,
            ),
          ),
        ],
      ),
    );
  }
}

/// White card with service / time / price summary rows.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lang});

  final AppLanguage lang;

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
        children: [
          _SummaryRow(
            label: tr(lang, 'Xizmat', 'Услуга', 'Service'),
            value: tr(lang, 'Smesitel almashtirish', 'Замена смесителя', 'Mixer replacement'),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: tr(lang, 'Vaqt', 'Время', 'Time'),
            value: tr(lang, 'Bugun, 12:00–15:00', 'Сегодня, 12:00–15:00', 'Today, 12:00–15:00'),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: tr(lang, 'Master taklifi', 'Предложение мастера', 'Master offer'),
            value: tr(lang, '50 000 soʻm', '50 000 сум', '50 000 sum'),
          ),
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
  const _PhotosCard({required this.lang});

  final AppLanguage lang;

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
          Text(
            tr(
              lang,
              'Bajarilgan ishdan 6 tagacha foto qoʻshing — mijozga koʻrsatish uchun',
              'Добавьте до 6 фото — мастеру будет проще оценить задачу',
              'Add up to 6 photos - it will be easier to assess the job',
            ),
            style: const TextStyle(
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
