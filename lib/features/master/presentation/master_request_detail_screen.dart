import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/presentation/master_offer_screen.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';

/// Detail of a single nearby request — full description, photos, address,
/// client and time, with respond / decline actions. Live data from
/// `GET /masters/me/feed/:id` (previously showed hardcoded mock data).
class MasterRequestDetailScreen extends StatefulWidget {
  const MasterRequestDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<MasterRequestDetailScreen> createState() =>
      _MasterRequestDetailScreenState();
}

class _MasterRequestDetailScreenState extends State<MasterRequestDetailScreen> {
  final MasterMarketplaceService _market = MasterMarketplaceService();
  FeedDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _market.feedDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Bottom sheet asking for a decline reason; declines on the backend + pops.
  Future<void> _showDeclineSheet(BuildContext context) async {
    final declined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x33797A7E),
      builder: (_) => const _DeclineSheet(),
    );
    if (declined == true && context.mounted) {
      try {
        await _market.decline(widget.orderId, 'busy');
      } catch (_) {}
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final d = _detail;
    return BrandedScaffold(
      title:
          tr(lang, 'Buyurtma', 'Заказ', 'Request') +
          (d != null ? ' #${d.id}' : ''),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || d == null
            ? Center(
                child: Text(
                  tr(
                    lang,
                    'Buyurtmani yuklab boʻlmadi',
                    'Не удалось загрузить заявку',
                    'Could not load the request',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8D96A4)),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category chip (real category name).
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.water_drop_outlined,
                                size: 18,
                                color: AppColors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                d.categoryName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navy,
                          ),
                        ),
                        if (d.photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          // Real photo thumbnails (presigned URLs).
                          Row(
                            children: [
                              for (
                                var i = 0;
                                i < d.photos.length && i < 4;
                                i++
                              ) ...[
                                if (i != 0) const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    d.photos[i],
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: [
                            d.district,
                            d.addressText,
                          ].where((s) => s != null && s.isNotEmpty).join(', '),
                        ),
                        if (d.clientName != null &&
                            d.clientName!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.person_outline,
                            text:
                                '${tr(lang, 'Mijoz', 'Клиент', 'Client')} — ${d.clientName}',
                          ),
                        ],
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.near_me_outlined,
                          text: '${d.distanceKm} ${tr(lang, 'km', 'км', 'km')}',
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.schedule,
                          text: orderTimingLabel(
                            lang,
                            timing: d.timing,
                            scheduledDate: d.scheduledDate,
                            slotLabel: d.slotLabel,
                          ),
                        ),
                        if (d.budgetMax != null) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            text:
                                '${tr(lang, 'Byudjet', 'Бюджет', 'Budget')}: '
                                '${d.budgetMax} ${tr(lang, 'soʻm', 'сум', 'sum')}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: d.hasOffer
                        ? tr(
                            lang,
                            'Javob yuborilgan',
                            'Ответ отправлен',
                            'Response sent',
                          )
                        : tr(lang, 'Javob berish', 'Откликнуться', 'Respond'),
                    onPressed: d.hasOffer
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MasterOfferScreen(orderId: widget.orderId),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () => _showDeclineSheet(context),
                      child: Text(
                        tr(
                          lang,
                          'Buyurtmani rad etish',
                          'Отклонить заявку',
                          'Decline request',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF8D96A4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bottom sheet for picking a decline reason.
class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet();

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  static const _reasons = [
    _Reason('Bu vaqtda bandman', 'Сейчас занят', 'Busy at this time'),
    _Reason('Uzoq borish kerak', 'Далеко ехать', 'Too far to travel'),
    _Reason('Mening profilim emas', 'Не мой профиль', 'Not my specialty'),
    _Reason('Past byudjet', 'Низкий бюджет', 'Low budget'),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  lang,
                  'Buyurtmani rad etish?',
                  'Отклонить заявку?',
                  'Decline the request?',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF23232E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(
                  lang,
                  'Sababini koʻrsating — bu tanlovga yordam beradi',
                  'Укажите причину — это поможет выбору',
                  'Specify the reason - it helps with selection',
                ),
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _reasons.length; i++) ...[
                      if (i != 0) const SizedBox(height: 8),
                      _ReasonRow(
                        label: _reasons[i].text(lang),
                        selected: _selected == i,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      label: tr(lang, 'Orqaga', 'Назад', 'Back'),
                      filled: false,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetButton(
                      label: tr(lang, 'Rad etish', 'Отклонить', 'Decline'),
                      filled: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One decline-reason row — white pill with a radio dot.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.navy),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.blue : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.blue : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet action button — filled blue or light-gray.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.blue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: filled ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

/// Gray icon + gray label row used for address / client / time.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8D96A4)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8D96A4)),
        ),
      ],
    );
  }
}

class _Reason {
  const _Reason(this.uz, this.ru, this.en);

  final String uz;
  final String ru;
  final String en;

  String text(AppLanguage lang) => tr(lang, uz, ru, en);
}
