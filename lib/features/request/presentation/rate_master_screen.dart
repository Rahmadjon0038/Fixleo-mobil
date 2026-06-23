import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';

/// Rate the master after a completed order — star rating, quality tags and a
/// free-text review. All selections are kept in state. Mock data for now.
class RateMasterScreen extends StatefulWidget {
  const RateMasterScreen({super.key});

  @override
  State<RateMasterScreen> createState() => _RateMasterScreenState();
}

class _RateMasterScreenState extends State<RateMasterScreen> {
  static const _star = Color(0xFFFBBF24);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _gray = Color(0xFF8D96A4);

  static const _tags = [
    'Punktuallik',
    'Sifat',
    'Xushmuomalalik',
    'Tozalik',
    'Tezlik',
  ];

  final _controller = TextEditingController();

  int _rating = 4;
  final _selectedTags = <String>{'Punktuallik', 'Sifat', 'Tozalik'};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Sharhingiz uchun rahmat!')),
      );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Ustani baholang',
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
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'Sharh yuborish',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Aleksey Ivanov',
                style: TextStyle(
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.verified, size: 18, color: AppColors.blue),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Smesitel almashtirish · bugun',
            style: TextStyle(
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final tag in _tags) _tagChip(tag),
      ],
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
          const Text(
            'Usta ishi haqida fikr bildiring',
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
                    'Masalan: Usta qoʻyilgan vazifani aʼlo darajada bajardi, '
                    'hammaga tavsiya qilaman!',
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
}
