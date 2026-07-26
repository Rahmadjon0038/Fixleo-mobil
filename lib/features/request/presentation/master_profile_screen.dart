import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/request/data/feedback_service.dart';

/// Master profile — opened when the user taps "Tanlash" on a response.
/// Shows the master's stats, bio, rating breakdown, a review and work photos
/// before final confirmation (Figma node 361:11694).
class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key, required this.masterId});

  final int masterId;

  static const _gray = Color(0xFF8D96A4);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate600 = Color(0xFF475569);
  static const _starOrange = Color(0xFFF59E0B);

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  static const _gray = MasterProfileScreen._gray;
  static const _slate100 = MasterProfileScreen._slate100;
  static const _slate200 = MasterProfileScreen._slate200;
  static const _slate600 = MasterProfileScreen._slate600;
  static const _starOrange = MasterProfileScreen._starOrange;

  final MasterPublicService _service = MasterPublicService();
  MasterPublicProfile? _p;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _service.profile(widget.masterId);
      if (!mounted) return;
      setState(() {
        _p = p;
        _loading = false;
      });
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Usta', 'Мастер', 'Master'),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _p == null
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
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _profileCard(lang),
                          const SizedBox(height: 10),
                          _aboutCard(lang),
                          const SizedBox(height: 10),
                          _ratingCard(lang),
                          const SizedBox(height: 10),
                          _reviewsSection(lang),
                          const SizedBox(height: 10),
                          _photosCard(lang),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
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
                          'Javoblarga qaytish',
                          'Назад к откликам',
                          'Back to responses',
                        ),
                        style: const TextStyle(
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

  Widget _profileCard(AppLanguage lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 61,
                height: 61,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: _p!.avatarUrl?.isNotEmpty == true
                    ? Image.network(
                        _p!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person, size: 33, color: _gray),
                      )
                    : const Icon(Icons.person, size: 33, color: _gray),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _p?.name ?? tr(lang, 'Usta', 'Мастер', 'Master'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 24 / 20,
                              fontWeight: FontWeight.w500,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_p!.isTopMaster)
                          _badge(
                            tr(lang, 'Top usta', 'Топ-мастер', 'Top master'),
                          ),
                        if (_p!.ratingAvg != null)
                          _badge(
                            _p!.ratingAvg!.toStringAsFixed(1),
                            leadingStar: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(
                value: '${_p!.completedOrders}',
                label: tr(lang, 'buyurtma', 'заказа', 'orders'),
              ),
              _Stat(
                value: _p!.completionRate == null
                    ? '—'
                    : '${_p!.completionRate}%',
                label: tr(lang, 'bajarilgan', 'выполнено', 'completed'),
              ),
              _Stat(
                value: _p!.experienceYears == null
                    ? '—'
                    : tr(
                        lang,
                        '${_p!.experienceYears} yil',
                        '${_p!.experienceYears} лет',
                        '${_p!.experienceYears} yrs',
                      ),
                label: tr(lang, 'tajriba', 'опыт', 'experience'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Light slate pill badge ("Топ-мастер" / "★ 4.9").
  Widget _badge(String text, {bool leadingStar = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: leadingStar ? 8 : 10,
        vertical: leadingStar ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: _slate100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingStar) ...[
            const Icon(Icons.star_rounded, size: 16, color: _slate600),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: _slate600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(AppLanguage lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(tr(lang, 'Usta haqida', 'О мастере', 'About the master')),
          const SizedBox(height: 6),
          Text(
            _p!.bio?.trim().isNotEmpty == true
                ? _p!.bio!
                : tr(
                    lang,
                    'Usta hali o‘zi haqida ma’lumot kiritmagan',
                    'Мастер пока не добавил информацию о себе',
                    'The master has not added a bio yet',
                  ),
            style: _bodyStyle,
          ),
        ],
      ),
    );
  }

  /// Big score + orange stars on the left, 5..1 distribution bars on the
  /// right.
  Widget _ratingCard(AppLanguage lang) {
    final count = _p!.ratingCount;
    return _card(
      child: Row(
        children: [
          Column(
            children: [
              Text(
                _p!.ratingAvg?.toStringAsFixed(1) ?? '—',
                style: const TextStyle(
                  fontSize: 40,
                  height: 48 / 40,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < (_p!.ratingAvg?.round() ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: _starOrange,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(lang, '$count ta sharh', '$count отзывов', '$count reviews'),
                style: const TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  letterSpacing: -0.12,
                  color: _gray,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--) ...[
                  if (star != 5) const SizedBox(height: 5),
                  Row(
                    children: [
                      SizedBox(
                        width: 8,
                        child: Text(
                          '$star',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            letterSpacing: -0.12,
                            color: _gray,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ratingBar(
                          count == 0
                              ? 0
                              : ((_p!.ratingHist[star] ?? 0) / count)
                                    .clamp(0, 1)
                                    .toDouble(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One 6px histogram track with a blue [fraction]-wide fill.
  Widget _ratingBar(double fraction) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: _slate200,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _reviewsSection(AppLanguage lang) {
    final reviews = _p!.recentReviews;
    if (reviews.isEmpty) {
      return _card(
        child: Text(
          tr(
            lang,
            'Hozircha mijozlardan sharh yoʻq',
            'Пока нет отзывов от клиентов',
            'No client reviews yet',
          ),
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < reviews.length; i++) ...[
          if (i != 0) const SizedBox(height: 10),
          _reviewCard(lang, reviews[i]),
        ],
      ],
    );
  }

  Widget _reviewCard(AppLanguage lang, PublicReview review) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.clientName?.trim().isNotEmpty == true
                      ? review.clientName!
                      : tr(lang, 'Mijoz', 'Клиент', 'Client'),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 22 / 16,
                    letterSpacing: -0.18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 15,
                    color: _starOrange,
                  ),
                ),
              ),
            ],
          ),
          if (review.text?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(review.text!, style: _bodyStyle),
          ],
        ],
      ),
    );
  }

  /// Real portfolio photos uploaded by the master.
  Widget _photosCard(AppLanguage lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(tr(lang, 'Fotosuratlar', 'Фотографии', 'Photos')),
          const SizedBox(height: 8),
          if (_p!.portfolio.isEmpty)
            Text(
              tr(
                lang,
                'Hozircha ish rasmlari yoʻq',
                'Пока нет фотографий работ',
                'No work photos yet',
              ),
              style: _bodyStyle,
            )
          else
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _p!.portfolio.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _p!.portfolio[i],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: _slate200,
                      child: SizedBox(width: 64, height: 64),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _bodyStyle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: -0.16,
    color: _gray,
  );

  Widget _cardTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        height: 22 / 16,
        letterSpacing: -0.18,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    );
  }

  /// Shared white rounded card wrapper.
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// One of the three centered profile stats (value over label).
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.16,
              color: MasterProfileScreen._gray,
            ),
          ),
        ],
      ),
    );
  }
}
