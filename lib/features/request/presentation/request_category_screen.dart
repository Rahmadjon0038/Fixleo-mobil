import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';

/// First step of request creation: the client chooses one real backend
/// category before entering the task description and photos.
class RequestCategoryScreen extends StatefulWidget {
  const RequestCategoryScreen({super.key, this.service});

  final CategoryService? service;

  @override
  State<RequestCategoryScreen> createState() => _RequestCategoryScreenState();
}

class _RequestCategoryScreenState extends State<RequestCategoryScreen> {
  late final CategoryService _service = widget.service ?? CategoryService();
  List<Category> _categories = const [];
  int? _selectedId;
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
      final categories = await _service.getAll();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (!categories.any((item) => item.id == _selectedId)) {
          _selectedId = null;
        }
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      setState(() {
        _error = tr(
          lang,
          'Kategoriyalarni yuklab bo‘lmadi',
          'Не удалось загрузить категории',
          'Could not load categories',
        );
        _loading = false;
      });
    }
  }

  void _continue() {
    final selected = _categories
        .where((item) => item.id == _selectedId)
        .firstOrNull;
    if (selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewRequestScreen(
          categoryId: selected.id,
          categoryName: selected.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Xizmat turini tanlang',
        'Выберите услугу',
        'Choose a service',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                tr(
                  lang,
                  'Qanday usta kerak?',
                  'Какой мастер вам нужен?',
                  'What kind of master do you need?',
                ),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _content(lang)),
            const SizedBox(height: 14),
            PrimaryButton(
              label: tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
              onPressed: _selectedId == null ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppLanguage lang) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(
        _error!,
        action: TextButton(
          onPressed: _load,
          child: Text(tr(lang, 'Qayta urinish', 'Повторить', 'Retry')),
        ),
      );
    }
    if (_categories.isEmpty) {
      return _message(
        tr(
          lang,
          'Hozircha xizmat turlari yo‘q',
          'Пока нет доступных услуг',
          'No services are available yet',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category.id == _selectedId;
          return Semantics(
            button: true,
            selected: selected,
            label: category.name,
            child: InkWell(
              key: ValueKey('request-category-${category.id}'),
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => _selectedId = category.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? AppColors.blue : const Color(0xFFE2E8F0),
                    width: selected ? 2 : 1,
                  ),
                ),
                // Repeated grid item — .lite skips BackdropFilter to avoid
                // stacking blur passes across the grid.
                child: GlassContainer.lite(
                  tint: selected ? const Color(0xFFE8F2FD) : Colors.white,
                  borderRadius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFEAF3FE),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              requestCategoryIcon(category.name),
                              color: AppColors.blue,
                              size: 23,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: selected ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.blue,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _message(String text, {Widget? action}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8D96A4), fontSize: 14),
        ),
        if (action != null) Center(child: action),
      ],
    );
  }
}

IconData requestCategoryIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('сантех') || value.contains('santex')) {
    return Icons.water_drop_outlined;
  }
  if (value.contains('электр') || value.contains('elektr')) {
    return Icons.bolt_outlined;
  }
  if (value.contains('убор') || value.contains('tozal')) {
    return Icons.cleaning_services_outlined;
  }
  if (value.contains('техник') || value.contains('texnik')) {
    return Icons.kitchen_outlined;
  }
  if (value.contains('крас') ||
      value.contains('bo‘y') ||
      value.contains("bo'y") ||
      value.contains('paint')) {
    return Icons.format_paint_outlined;
  }
  if (value.contains('сбор') ||
      value.contains('мебел') ||
      value.contains('yig‘') ||
      value.contains("yig'")) {
    return Icons.chair_alt_outlined;
  }
  return Icons.handyman_outlined;
}
