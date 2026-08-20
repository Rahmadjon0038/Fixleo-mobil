import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/full_screen_photo_gallery.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/waiting_responses_screen.dart';

const _slotLabels = {
  's10_12': '10:00–12:00',
  's12_15': '12:00–15:00',
  's15_18': '15:00–18:00',
  's18_21': '18:00–21:00',
};

/// Step 5 (final) of the "new request" flow — review the assembled request,
/// then submit it via `POST /clients/me/orders`.
class ReviewRequestScreen extends StatefulWidget {
  const ReviewRequestScreen({super.key, required this.draft});

  final NewOrderDraft draft;

  @override
  State<ReviewRequestScreen> createState() => _ReviewRequestScreenState();
}

class _ReviewRequestScreenState extends State<ReviewRequestScreen> {
  static const _blue100 = Color(0xFFDBEAFE);
  static const _gray = Color(0xFF8D96A4);

  final OrderService _orders = OrderService();
  bool _sending = false;

  Future<void> _send() async {
    final lang = LocaleController.language.value;
    final d = widget.draft;
    if (!d.hasLocation || d.categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Maʼlumot yetarli emas',
              'Недостаточно данных',
              'Missing data',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final order = await _orders.create(
        categoryId: d.categoryId!,
        description: d.description,
        addressText: d.addressText,
        district: d.district,
        latitude: d.latitude!,
        longitude: d.longitude!,
        addressDetails: d.addressDetails,
        timing: d.timing,
        scheduledDate: d.scheduledDate,
        slot: d.slot,
        budgetMax: d.budgetMax,
        photoKeys: d.photoKeys,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WaitingResponsesScreen(orderId: order.id),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Arizani tekshiring',
        'Проверьте заявку',
        'Review the request',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 11),
                    _hintCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassButton(
              label: tr(
                lang,
                'Arizani yuborish',
                'Отправить заявку',
                'Send request',
              ),
              height: 52,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final lang = LocaleController.language.value;
    final d = widget.draft;
    final timeLabel = orderTimingLabel(
      lang,
      timing: d.timing,
      scheduledDate: d.scheduledDate,
      slotLabel: d.slot == null ? null : _slotLabels[d.slot],
    );
    return GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chip — nested inside an already-blurred card, so use
          // .lite to avoid stacking another BackdropFilter.
          GlassContainer.lite(
            tint: _blue100,
            borderRadius: 999,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icon/Waterdrop.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.blue,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  d.categoryName ?? tr(lang, 'Xizmat', 'Услуга', 'Service'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    letterSpacing: -0.16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            d.description,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
          if (d.photoKeys.isNotEmpty) const SizedBox(height: 6),
          if (d.photoKeys.isNotEmpty)
            Text(
              tr(
                lang,
                '${d.photoKeys.length} ta rasm',
                '${d.photoKeys.length} фото',
                '${d.photoKeys.length} photos',
              ),
              style: const TextStyle(fontSize: 13, color: _gray),
            ),
          if (d.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.photoPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => showFullScreenPhotoGallery(
                    context,
                    photos: d.photoPaths,
                    initialIndex: index,
                    isLocalFile: true,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(d.photoPaths[index]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: _gray,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _infoRow(Icons.location_on_outlined, d.addressText),
          const SizedBox(height: 6),
          _infoRow(Icons.access_time_rounded, timeLabel),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _gray),
        const SizedBox(width: 2),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.16,
            color: _gray,
          ),
        ),
      ],
    );
  }

  Widget _hintCard() {
    final lang = LocaleController.language.value;
    return GlassContainer(
      tint: _blue100,
      borderRadius: 30,
      padding: const EdgeInsets.all(16),
      child: Text(
        tr(
          lang,
          'Ustalar javoblarda narx taklif qiladi',
          'Мастера предложат цену в ответах',
          'Masters will offer prices in their replies',
        ),
        style: TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.blue),
      ),
    );
  }
}
