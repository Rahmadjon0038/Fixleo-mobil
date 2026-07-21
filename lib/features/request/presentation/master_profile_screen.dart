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
                          _reviewCard(lang),
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
                        tr(lang, 'Javoblarga qaytish', 'Назад к откликам', 'Back to responses'),
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
                child: const Icon(Icons.person, size: 33, color: _gray),
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
                    Row(
                      children: [
                        _badge(tr(lang, 'Top usta', 'Топ-мастер',
                            'Top master')),
                        const SizedBox(width: 6),
                        _badge('4.9', leadingStar: true),
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
                value: '124',
                label: tr(lang, 'buyurtma', 'заказа', 'orders'),
              ),
              _Stat(
                value: '98%',
                label: tr(lang, 'bajarilgan', 'выполнено', 'completed'),
              ),
              _Stat(
                value: tr(lang, '5 yil', '5 лет', '5 yrs'),
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
            tr(
              lang,
              '5 yillik tajribaga ega santexnik. Smesitel, quvurlarni '
                  'almashtirish, oqishlarni bartaraf etish. Ozoda va oʻz '
                  'vaqtida.',
              'Сантехник с опытом 5 лет. Замена смесителей, труб, устранение '
                  'течей. Аккуратно и в срок.',
              'Plumber with 5 years of experience. Replacing faucets and '
                  'pipes, fixing leaks. Neat and on time.',
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
    // Share of reviews per star (5 → 1), matching the Figma bar widths.
    const shares = [0.55, 0.34, 0.11, 0.04, 0.02];
    return _card(
      child: Row(
        children: [
          Column(
            children: [
              const Text(
                '4.9',
                style: TextStyle(
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
                  (_) => const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: _starOrange,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(lang, '124 ta sharh', '124 отзыва', '124 reviews'),
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
                      Expanded(child: _ratingBar(shares[5 - star])),
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

  /// Single review: author + orange stars header, text below.
  Widget _reviewCard(AppLanguage lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dilshod R.',
                  style: TextStyle(
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
                  (_) => const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: _starOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              lang,
              'Oʻz vaqtida keldi, hammasini ozoda qildi. Tavsiya qilaman!',
              'Пришёл вовремя, всё сделал аккуратно. Рекомендую!',
              'Arrived on time, did everything neatly. I recommend!',
            ),
            style: _bodyStyle,
          ),
        ],
      ),
    );
  }

  /// "Фотографии" — 4 rounded placeholder squares for the master's work
  /// photos.
  Widget _photosCard(AppLanguage lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(tr(lang, 'Fotosuratlar', 'Фотографии', 'Photos')),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _slate200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ],
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
