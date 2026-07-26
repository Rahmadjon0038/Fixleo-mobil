import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/feedback_service.dart';

/// Report a problem with a completed order — pick a reason and describe the
/// issue, submitted via `POST /clients/me/orders/:id/complaint`.
class OrderComplaintScreen extends StatefulWidget {
  const OrderComplaintScreen({super.key, this.orderId});

  final int? orderId;

  @override
  State<OrderComplaintScreen> createState() => _OrderComplaintScreenState();
}

class _OrderComplaintScreenState extends State<OrderComplaintScreen> {
  static const _blue50 = Color(0xFFEFF6FF);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _gray = Color(0xFF8D96A4);
  static const _reasonCodes = [
    'master_late',
    'work_quality',
    'overpriced',
    'other',
  ];

  final _controller = TextEditingController();
  final FeedbackService _feedback = FeedbackService();
  int _selected = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = LocaleController.language.value;
    final desc = _controller.text.trim();
    if (widget.orderId != null) {
      if (desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                lang,
                'Muammoni tavsiflang',
                'Опишите проблему',
                'Describe the issue',
              ),
            ),
          ),
        );
        return;
      }
      setState(() => _busy = true);
      try {
        await _feedback.complaint(
          widget.orderId!,
          reason: _reasonCodes[_selected.clamp(0, _reasonCodes.length - 1)],
          description: desc,
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Shikoyatingiz yuborildi',
              'Ваша жалоба отправлена',
              'Your complaint has been sent',
            ),
          ),
        ),
      );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final reasons = [
      tr(lang, 'Usta kechikdi', 'Мастер опоздал', 'The master was late'),
      tr(lang, 'Ish sifati', 'Качество работы', 'Work quality'),
      tr(lang, 'Oshirilgan narx', 'Завышенная цена', 'Overpriced'),
      tr(lang, 'Boshqa', 'Другое', 'Other'),
    ];
    return BrandedScaffold(
      title: tr(
        lang,
        'Buyurtma boʻyicha shikoyat',
        'Жалоба по заказу',
        'Order complaint',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _reasonsCard(reasons),
                    const SizedBox(height: 10),
                    _describeCard(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  tr(
                    lang,
                    'Shikoyat yuborish',
                    'Отправить жалобу',
                    'Send complaint',
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _infoBanner(),
          ],
        ),
      ),
    );
  }

  /// "What went wrong?" — single-select list of reasons.
  Widget _reasonsCard(List<String> reasons) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text(
              tr(
                LocaleController.language.value,
                'Nima notoʻgʻri ketdi?',
                'Что пошло не так?',
                'What went wrong?',
              ),
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                letterSpacing: -0.18,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < reasons.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _reasonTile(i, reasons),
          ],
        ],
      ),
    );
  }

  Widget _reasonTile(int index, List<String> reasons) {
    final selected = _selected == index;
    return GestureDetector(
      onTap: () => setState(() => _selected = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? _slate100 : _slate50,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reasons[index],
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.16,
                  color: AppColors.navy,
                ),
              ),
            ),
            _radio(selected),
          ],
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: selected ? null : Border.all(color: _slate300, width: 2),
      ),
      child: selected
          ? const Center(
              child: Icon(Icons.circle, size: 7, color: Colors.white),
            )
          : null,
    );
  }

  /// Free-text problem description.
  Widget _describeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              LocaleController.language.value,
              'Muammoni tasvirlang',
              'Опишите проблему',
              'Describe the issue',
            ),
            style: TextStyle(
              fontSize: 16,
              height: 22 / 16,
              letterSpacing: -0.18,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.navy,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText:
                    'Masalan: Usta qoʻpol muomala qilib, ishni tugatmay ketdi!',
                hintStyle: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: _gray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Light-blue moderation notice under the submit button.
  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Shikoyatni moderator 24 soat ichida koʻrib chiqadi',
        style: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
