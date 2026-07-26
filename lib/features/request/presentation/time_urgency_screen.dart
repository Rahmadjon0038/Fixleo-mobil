import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/presentation/review_request_screen.dart';

/// Step 4 of the "new request" flow — choose urgent, today, or a later date.
/// Urgent needs no slot; today needs only a slot; later needs date + slot.
class TimeUrgencyScreen extends StatefulWidget {
  const TimeUrgencyScreen({super.key, this.draft});

  final NewOrderDraft? draft;

  @override
  State<TimeUrgencyScreen> createState() => _TimeUrgencyScreenState();
}

class _TimeUrgencyScreenState extends State<TimeUrgencyScreen> {
  static const _slots = [
    '10:00–12:00',
    '12:00–15:00',
    '15:00–18:00',
    '18:00–21:00',
  ];
  static const _slotCodes = ['s10_12', 's12_15', 's15_18', 's18_21'];

  int _option = 0;
  int? _slot;
  DateTime? _scheduledDate;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _option = switch (draft?.timing) {
      'today' => 1,
      'scheduled' => 2,
      _ => 0,
    };
    final slotIndex = _slotCodes.indexOf(draft?.slot ?? '');
    _slot = slotIndex < 0 ? null : slotIndex;
    _scheduledDate = DateTime.tryParse(draft?.scheduledDate ?? '');
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _selectOption(int option) {
    setState(() {
      _option = option;
      _slot = null;
      if (option != 2) _scheduledDate = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 13)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scheduledDate = selected;
      _slot = null;
    });
  }

  void _continue() {
    final lang = LocaleController.language.value;
    if (_option == 1 && _slot == null) {
      _showMessage(
        tr(lang, 'Vaqtni tanlang', 'Выберите время', 'Choose a time'),
      );
      return;
    }
    if (_option == 2 && _scheduledDate == null) {
      _showMessage(
        tr(lang, 'Sanani tanlang', 'Выберите дату', 'Choose a date'),
      );
      return;
    }
    if (_option == 2 && _slot == null) {
      _showMessage(
        tr(lang, 'Vaqtni tanlang', 'Выберите время', 'Choose a time'),
      );
      return;
    }

    final draft = widget.draft ?? NewOrderDraft();
    final now = DateTime.now();
    switch (_option) {
      case 0: // urgent — now
        draft
          ..timing = 'asap'
          ..slot = null
          ..scheduledDate = null;
      case 1: // today, pick a slot
        draft
          ..timing = 'today'
          ..slot = _slotCodes[_slot!]
          ..scheduledDate = _ymd(now);
      default: // tomorrow or later
        draft
          ..timing = 'scheduled'
          ..slot = _slotCodes[_slot!]
          ..scheduledDate = _ymd(_scheduledDate!);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewRequestScreen(draft: draft)),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<({String title, String subtitle})> _options(AppLanguage lang) => [
    (
      title: tr(lang, 'Shoshilinch — hozir', 'Срочно — сейчас', 'Urgent — now'),
      subtitle: tr(
        lang,
        'Usta bir soat ichida yetib keladi',
        'Мастер приедет в течение часа',
        'The master arrives within an hour',
      ),
    ),
    (
      title: tr(lang, 'Bugun', 'Сегодня', 'Today'),
      subtitle: tr(
        lang,
        'Qulay vaqtni tanlang',
        'Выберите удобное время',
        'Choose a convenient time',
      ),
    ),
    (
      title: tr(
        lang,
        'Ertaga yoki keyinroq',
        'Завтра или позже',
        'Tomorrow or later',
      ),
      subtitle: tr(
        lang,
        'Sanani rejalashtirish',
        'Запланировать дату',
        'Schedule a date',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Usta qachon kerak',
        'Когда нужен мастер',
        'When do you need the master',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _optionsCard(lang),
                    if (_option == 1) ...[
                      const SizedBox(height: 14),
                      _slotsCard(
                        lang,
                        title: tr(
                          lang,
                          'Bugungi vaqtlar',
                          'Время на сегодня',
                          'Today\'s time slots',
                        ),
                      ),
                    ],
                    if (_option == 2) ...[
                      const SizedBox(height: 14),
                      _dateCard(lang),
                      if (_scheduledDate != null) ...[
                        const SizedBox(height: 14),
                        _slotsCard(
                          lang,
                          title: tr(
                            lang,
                            'Tanlangan kun vaqtlari',
                            'Время на выбранную дату',
                            'Times for the selected date',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // "Davom etish" — Figma pill: 52px tall, fully rounded.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
                  style: const TextStyle(
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

  Widget _optionsCard(AppLanguage lang) {
    final options = _options(lang);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            _OptionTile(
              title: options[i].title,
              subtitle: options[i].subtitle,
              selected: _option == i,
              onTap: () => _selectOption(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateCard(AppLanguage lang) {
    final value = _scheduledDate == null
        ? tr(lang, 'Sanani tanlang', 'Выберите дату', 'Choose a date')
        : _ymd(_scheduledDate!);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8D96A4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotsCard(AppLanguage lang, {required String title}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 3-column grid; the second row holds a single chip.
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Expanded(child: _slotChip(i, lang)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _slotChip(3, lang)),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotChip(int i, AppLanguage lang) {
    final selected = _slot == i;
    return GestureDetector(
      onTap: () => setState(() => _slot = i),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.background),
        ),
        child: Text(
          _slots[i],
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF8D96A4),
          ),
        ),
      ),
    );
  }
}

/// A single urgency option row with a radio indicator.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(32),
          border: selected
              ? Border.all(color: const Color(0xFF60A5FA), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      letterSpacing: -0.18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.16,
                      color: Color(0xFF8D96A4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// 22px radio indicator — filled blue with a white dot when selected.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue,
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
