import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';

/// Filters for the nearby-requests feed — categories (multi-select),
/// distance (single) and sort order (single).
class MasterFiltersScreen extends StatefulWidget {
  const MasterFiltersScreen({super.key});

  @override
  State<MasterFiltersScreen> createState() => _MasterFiltersScreenState();
}

class _MasterFiltersScreenState extends State<MasterFiltersScreen> {
  static const _categories = ['Santexnika', 'Elektrika', 'Tozalash', 'Mebel'];
  static const _distances = ['3 km gacha', '5 km gacha', '10 km gacha'];
  static const _sorts = ['Avval yangilari', 'Menga yaqinroq', 'Yuqori byudjet'];

  final _selectedCategories = <int>{0, 1};
  int _distance = 1;
  int _sort = 0;

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Filtrlar',
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories.
                  _Card(
                    title: 'Kategoriyalar',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _categories.length; i++)
                          _Chip(
                            label: _categories[i],
                            selected: _selectedCategories.contains(i),
                            onTap: () => setState(() {
                              if (!_selectedCategories.remove(i)) {
                                _selectedCategories.add(i);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Distance.
                  _Card(
                    title: 'Masofa',
                    child: Row(
                      children: [
                        for (var i = 0; i < _distances.length; i++) ...[
                          if (i != 0) const SizedBox(width: 8),
                          Expanded(
                            child: _Chip(
                              label: _distances[i],
                              selected: _distance == i,
                              fullWidth: true,
                              onTap: () => setState(() => _distance = i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Sort.
                  _Card(
                    title: 'Saralash',
                    titleWeight: FontWeight.w500,
                    child: Column(
                      children: [
                        for (var i = 0; i < _sorts.length; i++) ...[
                          if (i != 0) const SizedBox(height: 8),
                          _SortRow(
                            label: _sorts[i],
                            selected: _sort == i,
                            onTap: () => setState(() => _sort = i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: PrimaryButton(
              label: '12 ta buyurtmani koʻrsatish',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// White section card with a title and arbitrary content.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.titleWeight = FontWeight.w600,
  });

  final String title;
  final Widget child;
  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: titleWeight,
              color: const Color(0xFF23232E),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Pill chip — blue when selected, light-gray otherwise.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When true the chip stretches to its parent width and centers the label
  /// (distance pills). When false it shrink-wraps the label (category chips
  /// laid out in a Wrap).
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: fullWidth ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

/// One sort option — label with a radio dot on the right.
class _SortRow extends StatelessWidget {
  const _SortRow({
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
          color: selected ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
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
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// Round radio indicator — filled blue when selected.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

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
    );
  }
}
