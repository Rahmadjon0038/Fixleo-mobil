import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';

/// Final master onboarding step — pick which job categories to receive
/// requests for. Multi-select; at least one must be chosen to continue.
class MasterCategoriesScreen extends StatefulWidget {
  const MasterCategoriesScreen({super.key});

  @override
  State<MasterCategoriesScreen> createState() => _MasterCategoriesScreenState();
}

class _MasterCategoriesScreenState extends State<MasterCategoriesScreen> {
  static const _categories = [
    'Santexnika',
    'Elektrika',
    'Mayda taʼmir',
    'Mebel yigʻish',
    'Montajchilar',
    'Tozalash',
    'Maishiy texnika',
    'Koʻchishda yordam',
    'Maysazor oʻroqchi',
    'Enaga',
  ];

  // Сантехника is pre-selected to match the design.
  final _selected = <int>{0};

  void _toggle(int i) {
    setState(() {
      if (!_selected.remove(i)) _selected.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Xizmat turlari',
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 14, 20, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 4),
                      child: Text(
                        'Qaysi buyurtmalarni olishni tanlang.',
                        style: TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ),
                    for (var i = 0; i < _categories.length; i++) ...[
                      if (i != 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE2E8F0),
                        ),
                      _CategoryRow(
                        name: _categories[i],
                        selected: _selected.contains(i),
                        onTap: () => _toggle(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: PrimaryButton(
              label: 'Davom etish',
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MasterWorkZoneScreen(),
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/icon/Waterdrop.svg',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            _SelectDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// Round selection indicator — filled blue with a white center when chosen,
/// otherwise an empty gray-bordered circle.
class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.blue : const Color(0xFFE2E8F0),
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
    );
  }
}
