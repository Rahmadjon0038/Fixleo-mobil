import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:flutter/material.dart';
import 'package:fixleo/app/widgets/thousands_separator_input_formatter.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/data/master_service_price.dart';

/// One place for service selection and per-service UZS prices.
class MasterServicePricingScreen extends StatefulWidget {
  const MasterServicePricingScreen({super.key, this.service, this.categories});
  final MasterService? service;
  final CategoryService? categories;
  @override
  State<MasterServicePricingScreen> createState() =>
      _MasterServicePricingScreenState();
}

class _MasterServicePricingScreenState
    extends State<MasterServicePricingScreen> {
  late final _service = widget.service ?? MasterService();
  final _form = GlobalKey<FormState>();
  final _selected = <int>{};
  final _fields = <int, TextEditingController>{};
  final _original = <int, MasterServicePrice>{};
  List<Category> _categories = [];
  bool _loading = true,
      _failed = false,
      _saving = false,
      _dirty = false,
      _add = false;
  bool _missingOnly = false;
  String _query = '';
  AppLanguage get _lang => LocaleController.language.value;
  String _t(String uz, String ru, String en) => tr(_lang, uz, ru, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _service.servicePricing(),
        (widget.categories ?? CategoryService(audience: 'master')).getAll(),
      ]);
      if (!mounted) return;
      final pricing = results[0] as List<MasterServicePrice>;
      final available = results[1] as List<Category>;
      for (final field in _fields.values) {
        field.dispose();
      }
      _fields.clear();
      _original.clear();
      _selected.clear();
      final all = {for (final item in available) item.id: item};
      for (final item in pricing) {
        _original[item.category.id] = item;
        _selected.add(item.category.id);
        all.putIfAbsent(item.category.id, () => item.category);
      }
      _categories = all.values.toList();
      for (final item in _categories) {
        _fields[item.id] = TextEditingController(
          text: ThousandsSeparatorInputFormatter.format(
            _original[item.id]?.price?.toString() ?? '',
          ),
        );
      }
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  _t(
                    'O‘zgarishlar saqlanmagan',
                    'Изменения не сохранены',
                    'Unsaved changes',
                  ),
                ),
                content: Text(
                  _t(
                    'Saqlamasdan chiqasizmi?',
                    'Выйти без сохранения?',
                    'Leave without saving?',
                  ),
                ),
                actions: [
                  LiquidActionButton.text(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(_t('Qolish', 'Остаться', 'Stay')),
                  ),
                  LiquidActionButton.text(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(_t('Chiqish', 'Выйти', 'Leave')),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() => _dirty = false);
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final invalid = _selected.any((id) {
      final text = _fields[id]!.text;
      final price = ThousandsSeparatorInputFormatter.parse(text);
      return text.isNotEmpty &&
          (price == null || price < 1 || price > 2000000000);
    });
    if (invalid) {
      setState(() {
        _add = false;
        _missingOnly = false;
        _query = '';
      });
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Narx 1–2 000 000 000 so‘m bo‘lishi kerak',
              'Цена должна быть от 1 до 2 000 000 000 сум',
              'Prices must be between 1 and 2,000,000,000 UZS',
            ),
          ),
        ),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await _service.saveServicePricing(_selected.toList(), {
        for (final id in _selected)
          if (!(_original[id]?.locked ?? false))
            id: ThousandsSeparatorInputFormatter.parse(_fields[id]!.text),
      });
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Xizmatlar va narxlar saqlandi',
              'Услуги и цены сохранены',
              'Services and prices saved',
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        try {
          final fresh = await _service.servicePricing();
          if (!mounted) return;
          for (final item in fresh) {
            _original[item.category.id] = item;
            if (item.locked) {
              _selected.add(item.category.id);
              _fields[item.category.id]?.text =
                  ThousandsSeparatorInputFormatter.format(
                    item.price?.toString() ?? '',
                  );
            }
          }
        } catch (_) {
          /* Preserve edits when the lock refresh is offline. */
        }
      }
      if (!mounted) return;
      setState(() => _saving = false);
      // Keep entered values on a network failure or a newly acquired order lock.
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : _t(
                    'Saqlanmadi. Internetni tekshiring. Yangi buyurtma yoki taklif bo‘lsa, xizmatni yakunlangach tahrirlang.',
                    'Не сохранено. Проверьте интернет. При новом заказе или отклике редактирование доступно после завершения.',
                    'Not saved. Check your connection. A new order or pending offer can lock a service until completion.',
                  ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLanguage>(
    valueListenable: LocaleController.language,
    builder: (context, lang, _) {
      final ready = _selected
          .where(
            (id) =>
                (ThousandsSeparatorInputFormatter.parse(
                      _fields[id]?.text ?? '',
                    ) ??
                    0) >
                0,
          )
          .length;
      final visible = _categories
          .where(
            (item) =>
                (_add
                    ? !_selected.contains(item.id)
                    : _selected.contains(item.id)) &&
                item.matches(_query) &&
                (!_missingOnly || _add || _original[item.id]?.price == null),
          )
          .toList();
      return PopScope(
        canPop: !_dirty && !_saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: LiquidAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.navy,
            centerTitle: true,
            title: Text(
              _t('Xizmatlar va narxlar', 'Услуги и цены', 'Services & prices'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            leading: LiquidIconControl(
              child: IconButton(
                onPressed: _leave,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                )
              : _failed
              ? Center(
                  child: LiquidActionButton.filled(
                    onPressed: _load,
                    child: Text(_t('Qayta urinish', 'Повторить', 'Retry')),
                  ),
                )
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _summary(ready),
                      const SizedBox(height: 18),
                      LiquidSurface(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7EBF1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _tab(
                              false,
                              _t(
                                'Mening xizmatlarim',
                                'Мои услуги',
                                'My services',
                              ),
                            ),
                            _tab(
                              true,
                              _t('Xizmat qo‘shish', 'Добавить', 'Add services'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LiquidSearchField(
                        key: ValueKey(_add),
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                        decoration: InputDecoration(
                          hintText: _t(
                            'Xizmatni qidirish',
                            'Поиск услуги',
                            'Search services',
                          ),
                          hintStyle: const TextStyle(color: AppColors.muted),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.muted,
                            size: 21,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (!_add)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: LiquidFilterChip(
                              label: Text(
                                _t(
                                  'Narx kiritilmagan',
                                  'Без цены',
                                  'Missing prices',
                                ),
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _missingOnly
                                    ? AppColors.blue
                                    : AppColors.navy,
                              ),
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFFE5F2FF),
                              checkmarkColor: AppColors.blue,
                              side: BorderSide(
                                color: _missingOnly
                                    ? const Color(0xFFB4D9FF)
                                    : const Color(0xFFE3E8EF),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              selected: _missingOnly,
                              onSelected: (value) =>
                                  setState(() => _missingOnly = value),
                            ),
                          ),
                        ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 16,
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _t(
                                  'Xizmatlar topilmadi. «Xizmat qo‘shish» bo‘limidan tanlang.',
                                  'Услуги не найдены. Выберите их в разделе «Добавить».',
                                  'No services found. Choose services in the Add tab.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final item in visible) _row(item),
                    ],
                  ),
                ),
          bottomNavigationBar: _loading || _failed
              ? null
              : LiquidSurface(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: SizedBox(
                        height: 52,
                        child: LiquidActionButton.filled(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFECF0F5),
                            disabledForegroundColor: AppColors.muted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: !_dirty || _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _t(
                                          'O‘zgarishlarni saqlash',
                                          'Сохранить изменения',
                                          'Save changes',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );

  Widget _summary(int ready) => LiquidSurface(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE5F2FF), Color(0xFFF0F7FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD8EAFE)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: _selected.isEmpty ? 0 : ready / _selected.length,
                  strokeWidth: 3,
                  color: AppColors.blue,
                  backgroundColor: Colors.white,
                ),
              ),
              const Icon(
                Icons.price_check_rounded,
                color: AppColors.blue,
                size: 25,
              ),
            ],
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  '$ready / ${_selected.length} xizmat tayyor',
                  '$ready / ${_selected.length} услуг готовы',
                  '$ready / ${_selected.length} services ready',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _t(
                  'Narx kiriting — buyurtma oling. Narxsiz xizmatlar vaqtincha yopiq.',
                  'Укажите цены, чтобы получать заказы. Услуги без цены приостановлены.',
                  'Set prices to receive orders. Services without prices are paused.',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF586B85),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tab(bool value, String label) => Expanded(
    child: Semantics(
      selected: _add == value,
      child: LiquidMaterial(
        color: _add == value ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _saving
              ? null
              : () => setState(() {
                  _add = value;
                  _query = '';
                }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (value) ...[
                  Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: _add ? AppColors.blue : AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _add == value
                          ? AppColors.navy
                          : const Color(0xFF718096),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _row(Category item) {
    final locked = _original[item.id]?.locked ?? false;
    final priced =
        (ThousandsSeparatorInputFormatter.parse(_fields[item.id]!.text) ?? 0) >
        0;
    final color = locked
        ? const Color(0xFF718096)
        : priced
        ? const Color(0xFF22916A)
        : const Color(0xFFB97823);
    return LiquidSurface(
      key: ValueKey('service-${item.id}'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x030F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: item.imageUrl == null
                      ? _serviceIcon()
                      : Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 140,
                          errorBuilder: (_, error, trace) => _serviceIcon(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.localizedName(_lang),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              LiquidIconControl(
                child: IconButton(
                  tooltip: _add
                      ? _t('Qo‘shish', 'Добавить', 'Add')
                      : _t('Olib tashlash', 'Удалить', 'Remove'),
                  onPressed: locked || _saving
                      ? null
                      : () {
                          if (_add && _selected.length >= 50) {
                            AppFeedback.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _t(
                                    'Ko‘pi bilan 50 ta xizmat tanlang',
                                    'Выберите не более 50 услуг',
                                    'Select up to 50 services',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _add
                                ? _selected.add(item.id)
                                : _selected.remove(item.id);
                            _dirty = true;
                          });
                        },
                  icon: Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : _add
                        ? Icons.add_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: locked
                        ? AppColors.muted
                        : _add
                        ? AppColors.blue
                        : const Color(0xFFA6B2C3),
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
          if (!_add) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _fields[item.id],
              enabled: !locked && !_saving,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              inputFormatters: [
                ThousandsSeparatorInputFormatter(maxDigits: 10),
              ],
              onChanged: (_) => setState(() => _dirty = true),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                letterSpacing: .3,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final price = ThousandsSeparatorInputFormatter.parse(value);
                return price == null || price < 1 || price > 2000000000
                    ? _t(
                        '1–2 000 000 000 oralig‘ida kiriting',
                        'Введите от 1 до 2 000 000 000',
                        'Enter 1–2,000,000,000',
                      )
                    : null;
              },
              decoration: InputDecoration(
                labelText: _t('Sizning narxingiz', 'Ваша цена', 'Your price'),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF718096),
                ),
                suffixText: _t('so‘m', 'сум', 'UZS'),
                suffixStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF718096),
                ),
                hintText: '100 000',
                hintStyle: const TextStyle(
                  color: Color(0xFFB8C5D6),
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: locked
                    ? const Color(0xFFF3F5F8)
                    : const Color(0xFFF5F9FF),
                contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5EDF7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5EDF7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.blue,
                    width: 1.5,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : priced
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 14,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    locked
                        ? _t(
                            'Ochiq buyurtma bor — hozircha tahrirlab bo‘lmaydi',
                            'Есть открытый заказ — изменение недоступно',
                            'Open order or offer — editing locked',
                          )
                        : priced
                        ? _t(
                            'Buyurtmalar uchun faol',
                            'Приём заказов включён',
                            'Ready for new orders',
                          )
                        : _t(
                            'Narx kiriting — buyurtmalarni yoqing',
                            'Укажите цену для приёма заказов',
                            'Set a price to receive orders',
                          ),
                    style: TextStyle(fontSize: 11, height: 1.3, color: color),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _serviceIcon() => LiquidSurface(
    color: const Color(0xFFEDF4FD),
    child: const Icon(
      Icons.home_repair_service_outlined,
      size: 23,
      color: AppColors.blue,
    ),
  );
}
