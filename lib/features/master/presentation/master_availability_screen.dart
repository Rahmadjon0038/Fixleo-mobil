import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_availability.dart';
import 'package:fixleo/features/master/data/master_service.dart';

class MasterAvailabilityScreen extends StatefulWidget {
  const MasterAvailabilityScreen({super.key, this.service});
  final MasterService? service;

  @override
  State<MasterAvailabilityScreen> createState() =>
      _MasterAvailabilityScreenState();
}

class _MasterAvailabilityScreenState extends State<MasterAvailabilityScreen> {
  late final MasterService _service = widget.service ?? MasterService();
  List<MasterAvailabilityInterval> _items = [];
  bool _loading = true;
  bool _saving = false;
  bool _discarding = false;
  String? _error;
  String _savedSignature = '';

  String get _signature => _items
      .map((item) => '${item.weekday}:${item.startMinute}:${item.endMinute}')
      .join('|');
  bool get _hasChanges => _signature != _savedSignature;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final schedule = await _service.availability();
      if (mounted) {
        setState(() {
          _items = [...schedule.intervals];
          _items.sort(_compareIntervals);
          _savedSignature = _signature;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr(
            LocaleController.language.value,
            'Jadvalni yuklab bo‘lmadi',
            'Не удалось загрузить график',
            'Could not load the schedule',
          );
        });
      }
    }
  }

  int _compareIntervals(
    MasterAvailabilityInterval a,
    MasterAvailabilityInterval b,
  ) {
    final day = a.weekday.compareTo(b.weekday);
    return day == 0 ? a.startMinute.compareTo(b.startMinute) : day;
  }

  Future<void> _add(int weekday) async {
    final lang = LocaleController.language.value;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: tr(lang, 'Boshlanish vaqti', 'Начало работы', 'Start time'),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: tr(lang, 'Tugash vaqti', 'Конец работы', 'End time'),
    );
    if (end == null || !mounted) return;
    final startMinute = start.hour * 60 + start.minute;
    final endMinute = end.hour * 60 + end.minute;
    final overlaps = _items.any(
      (item) =>
          item.weekday == weekday &&
          startMinute < item.endMinute &&
          endMinute > item.startMinute,
    );
    if (startMinute >= endMinute || overlaps) {
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Vaqt oralig‘i noto‘g‘ri yoki ustma-ust',
              'Интервал неверный или пересекается',
              'The time range is invalid or overlaps',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _items.add(
        MasterAvailabilityInterval(
          weekday: weekday,
          startMinute: startMinute,
          endMinute: endMinute,
        ),
      );
      _items.sort(_compareIntervals);
    });
  }

  void _applyWorkweekTemplate() {
    setState(() {
      _items.removeWhere((item) => item.weekday >= 1 && item.weekday <= 5);
      for (var weekday = 1; weekday <= 5; weekday++) {
        _items.add(
          MasterAvailabilityInterval(
            weekday: weekday,
            startMinute: 9 * 60,
            endMinute: 18 * 60,
          ),
        );
      }
      _items.sort(_compareIntervals);
    });
  }

  void _clearAll() => setState(_items.clear);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveAvailability(_items);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedSignature = _signature;
      });
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              LocaleController.language.value,
              'Ish jadvali saqlandi',
              'Рабочее расписание сохранено',
              'Work schedule saved',
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              LocaleController.language.value,
              'Jadvalni saqlab bo‘lmadi. Qayta urinib ko‘ring.',
              'Не удалось сохранить график. Попробуйте ещё раз.',
              'Could not save the schedule. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  String _time(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  List<String> _days(AppLanguage lang) => [
    tr(lang, 'Dushanba', 'Понедельник', 'Monday'),
    tr(lang, 'Seshanba', 'Вторник', 'Tuesday'),
    tr(lang, 'Chorshanba', 'Среда', 'Wednesday'),
    tr(lang, 'Payshanba', 'Четверг', 'Thursday'),
    tr(lang, 'Juma', 'Пятница', 'Friday'),
    tr(lang, 'Shanba', 'Суббота', 'Saturday'),
    tr(lang, 'Yakshanba', 'Воскресенье', 'Sunday'),
  ];

  Future<void> _close() async {
    if (!_hasChanges) {
      Navigator.of(context).maybePop();
      return;
    }
    final lang = LocaleController.language.value;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          tr(
            lang,
            'O‘zgarishlar saqlanmagan',
            'Изменения не сохранены',
            'Unsaved changes',
          ),
        ),
        content: Text(
          tr(
            lang,
            'Jadvaldagi o‘zgarishlarni bekor qilib chiqasizmi?',
            'Выйти и отменить изменения в графике?',
            'Leave and discard your schedule changes?',
          ),
        ),
        actions: [
          LiquidActionButton.text(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr(lang, 'Qolish', 'Остаться', 'Stay')),
          ),
          LiquidActionButton.text(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr(lang, 'Chiqish', 'Выйти', 'Leave')),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _discarding = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final days = _days(lang);
    return PopScope(
      canPop: !_hasChanges || _discarding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: BrandedScaffold(
        title: tr(lang, 'Ish jadvalim', 'Мой график', 'My schedule'),
        showBack: true,
        onBack: _close,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 42,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 10),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            LiquidActionButton.text(
                              onPressed: _load,
                              child: Text(
                                tr(lang, 'Qayta urinish', 'Повторить', 'Retry'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          _scheduleSummary(lang),
                          const SizedBox(height: 12),
                          for (var weekday = 1; weekday <= 7; weekday++) ...[
                            _dayCard(lang, weekday, days[weekday - 1]),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              GlassButton(
                label: _saving
                    ? tr(lang, 'Saqlanmoqda…', 'Сохраняем…', 'Saving…')
                    : !_hasChanges
                    ? tr(
                        lang,
                        'Jadval saqlangan',
                        'График сохранён',
                        'Schedule saved',
                      )
                    : tr(
                        lang,
                        'Jadvalni saqlash',
                        'Сохранить график',
                        'Save schedule',
                      ),
                icon: !_hasChanges ? Icons.check_rounded : null,
                onPressed: _saving || !_hasChanges ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleSummary(AppLanguage lang) {
    final workingDays = _items.map((item) => item.weekday).toSet().length;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    lang,
                    'Faqat bo‘sh vaqtlaringiz mijozlarga ko‘rinadi. Bir kunga bir nechta oraliq qo‘shish mumkin.',
                    'Клиенты видят только свободное время. Можно добавить несколько интервалов на день.',
                    'Clients see only your free time. You can add several ranges per day.',
                  ),
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              lang,
              '$workingDays ish kuni · ${_items.length} vaqt oralig‘i',
              '$workingDays рабочих дней · ${_items.length} интервалов',
              '$workingDays work days · ${_items.length} time ranges',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LiquidActionButton.textIcon(
                onPressed: _applyWorkweekTemplate,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  tr(
                    lang,
                    'Dush–Jum 09:00–18:00',
                    'Пн–Пт 09:00–18:00',
                    'Mon–Fri 09:00–18:00',
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                LiquidActionButton.textIcon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(tr(lang, 'Tozalash', 'Очистить', 'Clear')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCard(AppLanguage lang, int weekday, String title) {
    final ranges = _items.where((item) => item.weekday == weekday).toList();
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              LiquidActionButton.textIcon(
                onPressed: () => _add(weekday),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(tr(lang, 'Vaqt qo‘shish', 'Добавить', 'Add time')),
              ),
            ],
          ),
          if (ranges.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr(lang, 'Dam olish kuni', 'Выходной', 'Day off'),
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else
            for (final range in ranges)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GlassContainer.lite(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 19,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${_time(range.startMinute)} — ${_time(range.endMinute)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(lang, 'O‘chirish', 'Удалить', 'Delete'),
                        onPressed: () => setState(() => _items.remove(range)),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
