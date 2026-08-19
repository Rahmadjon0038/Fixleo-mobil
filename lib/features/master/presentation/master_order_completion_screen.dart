import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';

/// Master's "finish the job" screen — order summary + a button to mark the
/// order completed (POST /masters/me/orders/:id/complete). The client then
/// confirms on their side.
class MasterOrderCompletionScreen extends StatefulWidget {
  const MasterOrderCompletionScreen({
    super.key,
    required this.orderId,
    this.service,
  });

  final int orderId;
  final MasterMarketplaceService? service;

  @override
  State<MasterOrderCompletionScreen> createState() =>
      _MasterOrderCompletionScreenState();
}

class _MasterOrderCompletionScreenState
    extends State<MasterOrderCompletionScreen> {
  late final MasterMarketplaceService _market;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _amount = TextEditingController();
  final List<XFile> _photos = [];
  MasterOrderDetail? _order;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _market = widget.service ?? MasterMarketplaceService();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await _market.orderDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.message);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 6 || _busy) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null && mounted) setState(() => _photos.add(file));
  }

  void _removePhoto(int index) {
    if (!_busy) setState(() => _photos.removeAt(index));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _complete() async {
    final order = _order;
    if (order == null) return;
    final lang = LocaleController.language.value;
    final isDemo = CurrentUser.instance.isDemo;
    int? finalAmount;
    if (order.priceType != 'fixed') {
      if (isDemo) {
        // No amount field is shown to a demo account — the backend masks
        // this value regardless, so any placeholder satisfies the API.
        finalAmount = 1000;
      } else {
        finalAmount = int.tryParse(_amount.text.replaceAll(RegExp(r'\s+'), ''));
        if (finalAmount == null || finalAmount < 1000) {
          _snack(
            tr(
              lang,
              'Yakuniy summani kiriting (kamida 1 000 soʻm)',
              'Введите итоговую сумму (минимум 1 000 сум)',
              'Enter the final amount (at least 1,000 sum)',
            ),
          );
          return;
        }
      }
    }
    setState(() => _busy = true);
    try {
      final photoKeys = <String>[];
      for (final photo in _photos) {
        photoKeys.add(await _market.uploadOrderPhoto(photo.path));
      }
      await _market.complete(
        widget.orderId,
        finalAmount: finalAmount,
        photoKeys: photoKeys,
      );
      if (!mounted) return;
      if (isDemo) {
        // A SnackBar would be cut off by pushAndRemoveUntil below (it tears
        // down this screen's Scaffold), so hold briefly before navigating.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1400),
            content: Text(
              tr(
                lang,
                'Rahmat! Ish muvaffaqiyatli yakunlandi.',
                'Спасибо! Работа успешно завершена.',
                'Thank you! The job was completed successfully.',
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MasterHomeScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(
        tr(
          lang,
          'Rasmlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
          'Не удалось загрузить фото. Попробуйте ещё раз.',
          'Could not upload the photos. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Buyurtmani yakunlash',
        'Завершение заказа',
        'Complete order',
      ),
      showBack: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
          ? Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _SummaryCard(lang: lang, order: _order!),
                      if (_order!.priceType != 'fixed' &&
                          !CurrentUser.instance.isDemo) ...[
                        const SizedBox(height: 10),
                        _AmountCard(lang: lang, controller: _amount),
                      ],
                      const SizedBox(height: 10),
                      _PhotosCard(
                        lang: lang,
                        photos: _photos,
                        onAdd: _pickPhoto,
                        onRemove: _removePhoto,
                        busy: _busy,
                      ),
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
                        : tr(
                            lang,
                            'Bajarildi deb belgilash',
                            'Отметить выполненным',
                            'Mark as completed',
                          ),
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
  const _SummaryCard({required this.lang, required this.order});

  final AppLanguage lang;
  final MasterOrderDetail order;

  String get _price {
    if (order.price == null) return '—';
    final digits = order.price.toString();
    final value = digits.replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$value ${tr(lang, 'soʻm', 'сум', 'sum')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SummaryRow(
            label: tr(lang, 'Xizmat', 'Услуга', 'Service'),
            value: order.title,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: tr(lang, 'Vaqt', 'Время', 'Time'),
            value: orderTimingLabel(
              lang,
              timing: order.timing,
              scheduledDate: order.scheduledDate,
              slotLabel: order.slotLabel,
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: tr(
              lang,
              'Master taklifi',
              'Предложение мастера',
              'Master offer',
            ),
            value: _price,
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.lang, required this.controller});

  final AppLanguage lang;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: GlassTextField(
        controller: controller,
        keyboardType: TextInputType.number,
        hintText: tr(lang, 'Yakuniy summa', 'Итоговая сумма', 'Final amount'),
        trailing: Text(
          tr(lang, 'soʻm', 'сум', 'sum'),
          style: const TextStyle(color: AppColors.muted),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}

/// White card with the hint text and a 3×2 photo grid (first cell adds photos).
class _PhotosCard extends StatelessWidget {
  const _PhotosCard({
    required this.lang,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.busy,
  });

  final AppLanguage lang;
  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              lang,
              'Bajarilgan ishdan 6 tagacha foto qoʻshing — mijozga koʻrsatish uchun',
              'Добавьте до 6 фото выполненной работы — для клиента',
              'Add up to 6 photos of the completed work for the client',
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
              if (photos.length < 6) _AddPhotoTile(onTap: busy ? null : onAdd),
              for (var i = 0; i < photos.length; i++)
                _PhotoCell(
                  path: photos[i].path,
                  onRemove: busy ? null : () => onRemove(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dashed "add photo" tile shown first in the grid.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.blue,
          radius: 16,
          dash: 6,
          gap: 4,
          strokeWidth: 1.5,
        ),
        child: GlassContainer.lite(
          tint: AppColors.background,
          borderRadius: 16,
          alignment: Alignment.center,
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            size: 24,
            color: AppColors.blue,
          ),
        ),
      ),
    );
  }
}

/// One real photo selected by the master, with a remove action.
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFFE2E8F0)),
          ),
        ),
        if (onRemove != null)
          Align(
            alignment: Alignment.topRight,
            child: IconButton.filled(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xAA0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(30, 30),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }
}

/// Light-blue rounded info banner.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      tint: const Color(0xFFDBEAFE),
      tintOpacityTop: 0.85,
      tintOpacityBottom: 0.7,
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
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
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
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
