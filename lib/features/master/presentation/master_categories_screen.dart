import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';

/// Final master onboarding step — pick which job categories to receive
/// requests for. Multi-select; at least one must be chosen to continue.
class MasterCategoriesScreen extends StatefulWidget {
  const MasterCategoriesScreen({super.key});

  @override
  State<MasterCategoriesScreen> createState() => _MasterCategoriesScreenState();
}

class _MasterCategoriesScreenState extends State<MasterCategoriesScreen> {
  final _categoryService = CategoryService();
  final _masterService = MasterService();

  List<Category> _categories = const [];
  final _selectedIds = <int>{};
  bool _loading = true;
  bool _saving = false;
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
      final categories = await _categoryService.getAll();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
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

  /// Saves the selected categories (`PUT /masters/me/categories`) then moves on.
  Future<void> _saveAndContinue() async {
    if (_selectedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _masterService.setCategories(_selectedIds.toList());
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MasterWorkZoneScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Xizmat turlari', 'Виды услуг', 'Service types'),
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : SingleChildScrollView(
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
                                padding:
                                    const EdgeInsets.only(left: 10, bottom: 4),
                                child: Text(
                                  tr(
                                    lang,
                                    'Qaysi buyurtmalarni olishni tanlang.',
                                    'Выберите, какие заказы получать.',
                                    'Choose which requests to receive.',
                                  ),
                                  style: TextStyle(
                                      fontSize: 14, color: AppColors.muted),
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
                                  name: _categories[i].name,
                                  selected:
                                      _selectedIds.contains(_categories[i].id),
                                  onTap: () => _toggle(_categories[i].id),
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
              label: _saving
                  ? tr(lang, 'Saqlanmoqda...', 'Сохранение...', 'Saving...')
                  : tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
              onPressed:
                  _selectedIds.isEmpty || _saving ? null : _saveAndContinue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple centered error message with a retry button.
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
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(tr(LocaleController.language.value, 'Qayta urinish',
                  'Повторить', 'Retry')),
            ),
          ],
        ),
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
