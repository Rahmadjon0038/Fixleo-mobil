import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/categories/presentation/category_image.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';

/// Grouped multi-select used in master onboarding and service settings.
class MasterCategoriesScreen extends StatefulWidget {
  const MasterCategoriesScreen({
    super.key,
    this.categoryService,
    this.masterService,
  });

  final CategoryService? categoryService;
  final MasterService? masterService;

  @override
  State<MasterCategoriesScreen> createState() => _MasterCategoriesScreenState();
}

class _MasterCategoriesScreenState extends State<MasterCategoriesScreen> {
  late final CategoryService _categoryService =
      widget.categoryService ?? CategoryService(audience: 'master');
  late final MasterService _masterService =
      widget.masterService ?? MasterService();
  final _searchController = TextEditingController();
  List<CategoryGroup> _groups = const [];
  final _selectedIds = <int>{};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _categoryService.getGroups();
      final master = await _masterService.me();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedIds
          ..clear()
          ..addAll(master.categories.map((category) => category.id));
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr(
          LocaleController.language.value,
          'Tarmoq xatosi',
          'Ошибка сети',
          'Network error',
        );
      });
    }
  }

  void _toggle(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _masterService.setCategories(_selectedIds.toList(growable: false));
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MasterWorkZoneScreen()));
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      final language = LocaleController.language.value;
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(language, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(language, 'Xizmatlaringiz', 'Ваши услуги', 'Your services'),
      showBack: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    language,
                    'Buyurtma oladigan barcha xizmatlarni belgilang',
                    'Отметьте все услуги, по которым хотите получать заказы',
                    'Select every service you want to receive requests for',
                  ),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                LiquidSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr(
                      language,
                      'Xizmat yoki teg bo‘yicha qidirish',
                      'Поиск услуги или тега',
                      'Search services or tags',
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.blue,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : LiquidIconControl(
                            child: IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppColors.blue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _content(language)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: PrimaryButton(
              label: _saving
                  ? tr(language, 'Saqlanmoqda...', 'Сохранение...', 'Saving...')
                  : tr(
                      language,
                      'Davom etish · ${_selectedIds.length}',
                      'Продолжить · ${_selectedIds.length}',
                      'Continue · ${_selectedIds.length}',
                    ),
              onPressed: _selectedIds.isEmpty || _saving
                  ? null
                  : _saveAndContinue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(AppLanguage language) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorState(message: _error!, onRetry: _load);

    final query = _searchController.text;
    final visibleGroups = _groups
        .map(
          (group) => (
            group: group,
            services: group.services
                .where((category) => category.matches(query))
                .toList(),
          ),
        )
        .where((entry) => entry.services.isNotEmpty)
        .toList();
    if (visibleGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr(
              language,
              'Mos xizmat topilmadi',
              'Подходящие услуги не найдены',
              'No matching services found',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: visibleGroups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final entry = visibleGroups[index];
          return _MasterServiceGroup(
            title: entry.group.localizedTitle(language),
            description: entry.group
                .localizedDescription(language)
                .replaceAll('**', ''),
            services: entry.services,
            language: language,
            selectedIds: _selectedIds,
            onToggle: _toggle,
          );
        },
      ),
    );
  }
}

class _MasterServiceGroup extends StatelessWidget {
  const _MasterServiceGroup({
    required this.title,
    required this.description,
    required this.services,
    required this.language,
    required this.selectedIds,
    required this.onToggle,
  });

  final String title;
  final String description;
  final List<Category> services;
  final AppLanguage language;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return _MasterServiceTile(
              service: service,
              language: language,
              selected: selectedIds.contains(service.id),
              onTap: () => onToggle(service.id),
            );
          },
        ),
      ],
    );
  }
}

class _MasterServiceTile extends StatelessWidget {
  const _MasterServiceTile({
    required this.service,
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final Category service;
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: service.localizedName(language),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: LiquidAnimatedSurface(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF3FE) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.blue : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CategoryImage(category: service, borderRadius: 15),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: selected ? AppColors.blue : Colors.white,
                        size: 25,
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 7),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
                child: Text(
                  service.localizedName(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            LiquidActionButton.text(
              onPressed: onRetry,
              child: Text(
                tr(
                  LocaleController.language.value,
                  'Qayta urinish',
                  'Повторить',
                  'Retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
