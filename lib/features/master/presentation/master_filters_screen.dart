import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';

class MasterFeedFilters {
  const MasterFeedFilters({
    this.categoryIds = const [],
    this.radiusKm = 10,
    this.sort = 'new',
  });

  final List<int> categoryIds;
  final int radiusKm;
  final String sort;
}

/// Filters for the nearby-requests feed — categories (multi-select),
/// distance (single) and sort order (single).
class MasterFiltersScreen extends StatefulWidget {
  const MasterFiltersScreen({
    super.key,
    this.initial = const MasterFeedFilters(),
    this.categories = const [],
    this.service,
  });

  final MasterFeedFilters initial;
  final List<Category> categories;
  final MasterMarketplaceService? service;

  @override
  State<MasterFiltersScreen> createState() => _MasterFiltersScreenState();
}

class _MasterFiltersScreenState extends State<MasterFiltersScreen> {
  static const _distances = [3, 5, 10];
  static const _sortCodes = ['new', 'near', 'budget'];

  late final MasterMarketplaceService _market;
  late final Set<int> _selectedCategories;
  late int _distance;
  late String _sort;
  List<Category> _categories = const [];
  bool _loadingCategories = true;
  int? _resultCount;
  int _countRequest = 0;

  @override
  void initState() {
    super.initState();
    _market = widget.service ?? MasterMarketplaceService();
    _selectedCategories = widget.initial.categoryIds.toSet();
    _distance = _distances.contains(widget.initial.radiusKm)
        ? widget.initial.radiusKm
        : 10;
    _sort = _sortCodes.contains(widget.initial.sort)
        ? widget.initial.sort
        : 'new';
    if (widget.categories.isNotEmpty) {
      _categories = widget.categories;
      _normalizeSelection();
      _loadingCategories = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCount());
    } else {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService(audience: 'master').getAll();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _normalizeSelection();
        _loadingCategories = false;
      });
      _refreshCount();
    } on Object {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _normalizeSelection() {
    final available = _categories.map((c) => c.id).toSet();
    _selectedCategories.retainWhere(available.contains);
    if (_selectedCategories.isEmpty) {
      _selectedCategories.addAll(available);
    }
  }

  Future<void> _refreshCount() async {
    final request = ++_countRequest;
    if (mounted) setState(() => _resultCount = null);
    try {
      final count = await _market.feedCount(
        categoryIds: _selectedCategories.toList(growable: false),
        radiusKm: _distance,
        sort: _sort,
      );
      if (mounted && request == _countRequest) {
        setState(() => _resultCount = count);
      }
    } on Object {
      if (mounted && request == _countRequest) {
        setState(() => _resultCount = null);
      }
    }
  }

  void _toggleCategory(int id) {
    setState(() {
      if (_selectedCategories.contains(id)) {
        if (_selectedCategories.length > 1) _selectedCategories.remove(id);
      } else {
        _selectedCategories.add(id);
      }
    });
    _refreshCount();
  }

  void _setDistance(int value) {
    setState(() => _distance = value);
    _refreshCount();
  }

  void _setSort(String value) {
    setState(() => _sort = value);
    _refreshCount();
  }

  void _apply() {
    Navigator.of(context).pop(
      MasterFeedFilters(
        categoryIds: _selectedCategories.toList(growable: false),
        radiusKm: _distance,
        sort: _sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final distanceLabels = [
      tr(lang, '3 km gacha', 'До 3 км', 'Up to 3 km'),
      tr(lang, '5 km gacha', 'До 5 км', 'Up to 5 km'),
      tr(lang, '10 km gacha', 'До 10 км', 'Up to 10 km'),
    ];
    final sorts = [
      tr(lang, 'Avval yangilari', 'Сначала новые', 'Newest first'),
      tr(lang, 'Menga yaqinroq', 'Ближе ко мне', 'Closer to me'),
      tr(lang, 'Yuqori byudjet', 'Высокий бюджет', 'Higher budget'),
    ];
    return BrandedScaffold(
      title: tr(lang, 'Filtrlar', 'Фильтры', 'Filters'),
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
                    title: tr(lang, 'Kategoriyalar', 'Категории', 'Categories'),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_loadingCategories)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_categories.isEmpty)
                          Text(
                            tr(
                              lang,
                              'Kategoriyalar topilmadi',
                              'Категории не найдены',
                              'No categories found',
                            ),
                            style: const TextStyle(color: Color(0xFF8D96A4)),
                          )
                        else
                          for (final category in _categories)
                            _Chip(
                              label: category.name,
                              selected: _selectedCategories.contains(
                                category.id,
                              ),
                              onTap: () => _toggleCategory(category.id),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Distance.
                  _Card(
                    title: tr(lang, 'Masofa', 'Расстояние', 'Distance'),
                    child: Row(
                      children: [
                        for (var i = 0; i < _distances.length; i++) ...[
                          if (i != 0) const SizedBox(width: 8),
                          Expanded(
                            child: _Chip(
                              label: distanceLabels[i],
                              selected: _distance == _distances[i],
                              fullWidth: true,
                              onTap: () => _setDistance(_distances[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Sort.
                  _Card(
                    title: tr(lang, 'Saralash', 'Сортировка', 'Sort'),
                    titleWeight: FontWeight.w500,
                    child: Column(
                      children: [
                        for (var i = 0; i < sorts.length; i++) ...[
                          if (i != 0) const SizedBox(height: 8),
                          _SortRow(
                            label: sorts[i],
                            selected: _sort == _sortCodes[i],
                            onTap: () => _setSort(_sortCodes[i]),
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
              label: _resultCount == null
                  ? tr(
                      lang,
                      'Buyurtmalarni ko‘rsatish',
                      'Показать заказы',
                      'Show requests',
                    )
                  : tr(
                      lang,
                      '$_resultCount ta buyurtmani ko‘rsatish',
                      'Показать $_resultCount заказов',
                      'Show $_resultCount requests',
                    ),
              onPressed: _loadingCategories || _categories.isEmpty
                  ? null
                  : _apply,
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
    return GlassContainer(
      width: double.infinity,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      child: LiquidSurface(
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
      child: LiquidSurface(
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
    return LiquidSurface(
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
              child: LiquidSurface(
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
