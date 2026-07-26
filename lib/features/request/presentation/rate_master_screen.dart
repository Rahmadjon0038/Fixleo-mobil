import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/feedback_service.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/data/order_timing_label.dart';

/// Rate the master after a completed order — star rating, quality tags and a
/// free-text review, submitted via `POST /clients/me/orders/:id/review`.
class RateMasterScreen extends StatefulWidget {
  const RateMasterScreen({
    super.key,
    this.orderId,
    this.orderService,
    this.feedbackService,
  });

  final int? orderId;
  final OrderService? orderService;
  final FeedbackService? feedbackService;

  @override
  State<RateMasterScreen> createState() => _RateMasterScreenState();
}

class _RateMasterScreenState extends State<RateMasterScreen> {
  static const _star = Color(0xFFFBBF24);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _gray = Color(0xFF8D96A4);
  static const _tagCodes = [
    'punctuality',
    'quality',
    'politeness',
    'cleanliness',
    'speed',
  ];

  final _controller = TextEditingController();
  late final FeedbackService _feedback =
      widget.feedbackService ?? FeedbackService();
  late final OrderService _orders = widget.orderService ?? OrderService();

  int _rating = 5;
  bool _busy = false;
  OrderDetail? _order;
  final _selectedTags = <String>{};

  List<String> _tagLabels(AppLanguage lang) => [
    tr(lang, 'Punktuallik', 'Пунктуальность', 'Punctuality'),
    tr(lang, 'Sifat', 'Качество', 'Quality'),
    tr(lang, 'Xushmuomalalik', 'Вежливость', 'Courtesy'),
    tr(lang, 'Tozalik', 'Чистота', 'Cleanliness'),
    tr(lang, 'Tezlik', 'Скорость', 'Speed'),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    if (widget.orderId == null) return;
    try {
      final order = await _orders.detail(widget.orderId!);
      if (mounted) setState(() => _order = order);
    } on ApiException {
      // Rating remains available even if the header cannot be refreshed.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = LocaleController.language.value;
    if (widget.orderId != null) {
      final labels = _tagLabels(lang);
      final codes = <String>[
        for (var i = 0; i < labels.length; i++)
          if (_selectedTags.contains(labels[i])) _tagCodes[i],
      ];
      setState(() => _busy = true);
      try {
        await _feedback.review(
          widget.orderId!,
          rating: _rating,
          tags: codes,
          text: _controller.text.trim(),
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
              'Sharhingiz uchun rahmat!',
              'Спасибо за ваш отзыв!',
              'Thanks for your review!',
            ),
          ),
        ),
      );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Ustani baholang', 'Оцените мастера', 'Rate the master'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _masterCard(),
                    const SizedBox(height: 10),
                    _reviewCard(),
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
                    'Sharh yuborish',
                    'Отправить отзыв',
                    'Submit review',
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
          ],
        ),
      ),
    );
  }

  /// Master header: avatar, name, service, star rating and quality tags.
  Widget _masterCard() {
    final lang = LocaleController.language.value;
    final master = _order?.master;
    final name = master?.name?.trim().isNotEmpty == true
        ? master!.name!.trim()
        : tr(lang, 'Usta', 'Мастер', 'Master');
    final serviceTitle = _order?.title.trim().isNotEmpty == true
        ? _order!.title.trim()
        : tr(
            lang,
            'Bajarilgan buyurtma',
            'Выполненный заказ',
            'Completed order',
          );
    final timing = _order == null
        ? ''
        : orderTimingLabel(
            lang,
            timing: _order!.timing,
            scheduledDate: _order!.scheduledDate,
            slotLabel: _order!.slotLabel,
          );
    final avatarUrl = master?.avatarUrl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 61,
              height: 61,
              color: AppColors.background,
              child: avatarUrl?.isNotEmpty == true
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.person, size: 33, color: _gray),
                    )
                  : const Icon(Icons.person, size: 33, color: _gray),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.verified, size: 18, color: AppColors.blue),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            timing.isEmpty ? serviceTitle : '$serviceTitle · $timing',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: _gray,
            ),
          ),
          const SizedBox(height: 12),
          _stars(),
          const SizedBox(height: 14),
          _tagsWrap(),
        ],
      ),
    );
  }

  /// Five tappable stars; tapping sets the rating to that position.
  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i != 1) const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _rating = i),
            child: Icon(
              Icons.star_rounded,
              size: 32,
              color: i <= _rating ? _star : _slate200,
            ),
          ),
        ],
      ],
    );
  }

  /// Selectable quality tags (multi-select chips).
  Widget _tagsWrap() {
    final lang = LocaleController.language.value;
    final tags = [
      tr(lang, 'Punktuallik', 'Пунктуальность', 'Punctuality'),
      tr(lang, 'Sifat', 'Качество', 'Quality'),
      tr(lang, 'Xushmuomalalik', 'Вежливость', 'Courtesy'),
      tr(lang, 'Tozalik', 'Чистота', 'Cleanliness'),
      tr(lang, 'Tezlik', 'Скорость', 'Speed'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [for (final tag in tags) _tagChip(tag)],
    );
  }

  Widget _tagChip(String tag) {
    final selected = _selectedTags.contains(tag);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedTags.remove(tag);
        } else {
          _selectedTags.add(tag);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.background,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : _gray,
          ),
        ),
      ),
    );
  }

  /// Free-text review card.
  Widget _reviewCard() {
    final lang = LocaleController.language.value;
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
              lang,
              'Usta ishi haqida fikr bildiring',
              'Расскажите о работе мастера',
              'Share feedback about the master’s work',
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
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: tr(
                  lang,
                  'Masalan: Usta qoʻyilgan vazifani aʼlo darajada bajardi, hammaga tavsiya qilaman!',
                  'Например: мастер отлично выполнил задачу, всем рекомендую!',
                  'For example: the master did an excellent job; I recommend them to everyone!',
                ),
                hintStyle: const TextStyle(
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
}
