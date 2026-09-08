import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/categories/data/service_question.dart';
import 'package:fixleo/features/categories/presentation/category_image.dart';
import 'package:fixleo/features/request/presentation/service_questions_screen.dart';

/// First request step: search and choose a service from localized visual groups.
class RequestCategoryScreen extends StatefulWidget {
  const RequestCategoryScreen({
    super.key,
    this.service,
    this.questionService,
    this.autofocusSearch = false,
  });

  final CategoryService? service;
  final ServiceQuestionService? questionService;
  final bool autofocusSearch;

  static String searchHint(AppLanguage language) => tr(
    language,
    'Masalan: kran, televizor yoki tozalash',
    'Например: кран, телевизор или уборка',
    'Try faucet, TV mounting or cleaning',
  );

  @override
  State<RequestCategoryScreen> createState() => _RequestCategoryScreenState();
}

class _RequestCategoryScreenState extends State<RequestCategoryScreen> {
  late final CategoryService _service = widget.service ?? CategoryService();
  final _searchController = TextEditingController();
  List<CategoryGroup> _groups = const [];
  int? _selectedId;
  bool _loading = true;
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
      final groups = await _service.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        if (!_allServices.any((service) => service.id == _selectedId)) {
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
      final language = LocaleController.language.value;
      setState(() {
        _error = tr(
          language,
          'Xizmatlarni yuklab bo‘lmadi',
          'Не удалось загрузить услуги',
          'Could not load services',
        );
        _loading = false;
      });
    }
  }

  List<Category> get _allServices =>
      _groups.expand((group) => group.services).toList(growable: false);

  void _continue() {
    final selected = _allServices
        .where((item) => item.id == _selectedId)
        .firstOrNull;
    if (selected == null) return;
    final language = LocaleController.language.value;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceQuestionsScreen(
          service: widget.questionService,
          categoryId: selected.id,
          categoryName: selected.localizedName(language),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        language,
        'Xizmat tanlang',
        'Выберите услугу',
        'Choose a service',
      ),
      showBack: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: _SearchField(
              controller: _searchController,
              autofocus: widget.autofocusSearch,
              hint: RequestCategoryScreen.searchHint(language),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(child: _content(language)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: PrimaryButton(
              label: tr(language, 'Davom etish', 'Продолжить', 'Continue'),
              onPressed: _selectedId == null ? null : _continue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(AppLanguage language) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(
        message: _error!,
        action: TextButton(
          onPressed: _load,
          child: Text(tr(language, 'Qayta urinish', 'Повторить', 'Retry')),
        ),
      );
    }
    if (_groups.isEmpty) {
      return _MessageState(
        message: tr(
          language,
          'Hozircha xizmatlar yo‘q',
          'Пока нет доступных услуг',
          'No services are available yet',
        ),
      );
    }

    final query = _searchController.text;
    final visibleGroups = _groups
        .map(
          (group) => (
            group: group,
            services: group.services
                .where((service) => service.matches(query))
                .toList(),
          ),
        )
        .where((entry) => entry.services.isNotEmpty)
        .toList();
    if (visibleGroups.isEmpty) {
      return _MessageState(
        message: tr(
          language,
          'Qidiruv bo‘yicha xizmat topilmadi',
          'По вашему запросу ничего не найдено',
          'No services match your search',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: visibleGroups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final entry = visibleGroups[index];
          return _ServiceGroupSection(
            title: entry.group.localizedTitle(language),
            description: entry.group
                .localizedDescription(language)
                .replaceAll('**', ''),
            services: entry.services,
            language: language,
            selectedId: _selectedId,
            onSelected: (id) => setState(() => _selectedId = id),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.autofocus,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA3AF), fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
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
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
      ),
    );
  }
}

class _ServiceGroupSection extends StatelessWidget {
  const _ServiceGroupSection({
    required this.title,
    required this.description,
    required this.services,
    required this.language,
    required this.selectedId,
    required this.onSelected,
  });

  final String title;
  final String description;
  final List<Category> services;
  final AppLanguage language;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
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
        SizedBox(
          height: 194,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final service = services[index];
              final isSelected = service.id == selectedId;
              return _ServiceCard(
                service: service,
                language: language,
                isSelected: isSelected,
                onTap: () => onSelected(service.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final Category service;
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: service.localizedName(language),
      child: InkWell(
        key: ValueKey('request-category-${service.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 172,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.blue : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CategoryImage(category: service, borderRadius: 15),
                    if (isSelected)
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.blue,
                          size: 25,
                        ),
                      ),
                    if (service.requiresTools)
                      const Positioned(
                        left: 8,
                        top: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xEFFFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.handyman_outlined,
                              color: AppColors.navy,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 9, 7, 8),
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

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8D96A4), fontSize: 14),
        ),
        if (action != null) Center(child: action),
      ],
    );
  }
}
