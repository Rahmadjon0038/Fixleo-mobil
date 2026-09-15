import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/app_feedback.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/request/data/new_order_draft.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/review_request_screen.dart';

/// Step 4: fastest possible service or one exact future appointment.
class TimeUrgencyScreen extends StatefulWidget {
  const TimeUrgencyScreen({super.key, this.draft, this.orderService});

  final NewOrderDraft? draft;
  final OrderService? orderService;

  @override
  State<TimeUrgencyScreen> createState() => _TimeUrgencyScreenState();
}

class _TimeUrgencyScreenState extends State<TimeUrgencyScreen> {
  late final OrderService _orders = widget.orderService ?? OrderService();
  int _option = 0;
  DateTime? _scheduledAt;
  OrderSlots? _availability;
  bool _loadingAvailability = true;
  bool _availabilityFailed = false;

  @override
  void initState() {
    super.initState();
    _option = widget.draft?.timing == 'scheduled' ? 1 : 0;
    _scheduledAt = widget.draft?.scheduledAt;
    _loadUrgentAvailability();
  }

  Future<void> _loadUrgentAvailability() async {
    if (mounted) setState(() => _loadingAvailability = true);
    try {
      final value = await _orders.slots();
      if (mounted) {
        setState(() {
          _availability = value;
          _loadingAvailability = false;
          _availabilityFailed = false;
          if (!value.asapAvailable && _option == 0) _option = 1;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingAvailability = false;
          _availabilityFailed = true;
          if (_option == 0) _option = 1;
        });
      }
    }
  }

  bool get _urgentAvailable =>
      !_loadingAvailability && (_availability?.asapAvailable ?? false);

  static String _ymd(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickAppointment() async {
    final lang = LocaleController.language.value;
    final now = DateTime.now();
    final suggested = _scheduledAt ?? now.add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: suggested,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 14)),
      helpText: tr(lang, 'Keladigan kun', 'Дата визита', 'Visit date'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(suggested),
      helpText: tr(lang, 'Aniq vaqt', 'Точное время', 'Exact time'),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Kamida 1 soat keyingi vaqtni tanlang',
              'Выберите время минимум через 1 час',
              'Choose a time at least 1 hour from now',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _scheduledAt = selected);
  }

  void _continue() {
    final lang = LocaleController.language.value;
    if (_option == 0 && !_urgentAvailable) {
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Tezkor xizmat hozir mavjud emas',
              'Срочный заказ сейчас недоступен',
              'Urgent service is unavailable now',
            ),
          ),
        ),
      );
      return;
    }
    if (_option == 1 && _scheduledAt == null) {
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              lang,
              'Sana va vaqtni tanlang',
              'Выберите дату и время',
              'Choose date and time',
            ),
          ),
        ),
      );
      return;
    }
    final draft = widget.draft ?? NewOrderDraft();
    if (_option == 0) {
      draft
        ..timing = 'asap'
        ..scheduledDate = null
        ..scheduledAt = null
        ..slot = null;
    } else {
      draft
        ..timing = 'scheduled'
        ..scheduledDate = _ymd(_scheduledAt!)
        ..scheduledAt = _scheduledAt
        ..slot = null;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReviewRequestScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final canContinue =
        !_loadingAvailability &&
        (_option == 0 ? _urgentAvailable : _scheduledAt != null);
    return BrandedScaffold(
      title: tr(
        lang,
        'Usta qachon kerak?',
        'Когда нужен мастер?',
        'When do you need a master?',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  GlassCard(
                    radius: 24,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _TimingTile(
                          icon: Icons.bolt_rounded,
                          title: tr(lang, 'Shoshilinch', 'Срочно', 'Urgent'),
                          subtitle: _loadingAvailability
                              ? tr(
                                  lang,
                                  'Tekshirilmoqda…',
                                  'Проверяем…',
                                  'Checking…',
                                )
                              : _urgentAvailable
                              ? tr(
                                  lang,
                                  'Eng yaqin bo‘sh ustalarga darhol yuboriladi',
                                  'Сразу отправим ближайшим свободным мастерам',
                                  'Sent immediately to nearby available masters',
                                )
                              : tr(
                                  lang,
                                  'Hozir xizmat vaqti emas',
                                  'Сейчас недоступно',
                                  'Unavailable right now',
                                ),
                          selected: _option == 0,
                          disabled: !_loadingAvailability && !_urgentAvailable,
                          onTap: () => setState(() => _option = 0),
                        ),
                        if (_availabilityFailed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  size: 18,
                                  color: Color(0xFFB45309),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tr(
                                      lang,
                                      'Tezkor xizmatni tekshirib bo‘lmadi',
                                      'Не удалось проверить срочный заказ',
                                      'Could not check urgent availability',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                LiquidActionButton.text(
                                  onPressed: _loadUrgentAvailability,
                                  child: Text(
                                    tr(lang, 'Qayta', 'Повторить', 'Retry'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        _TimingTile(
                          icon: Icons.event_available_rounded,
                          title: tr(
                            lang,
                            'Rejalashtirish',
                            'Запланировать',
                            'Schedule',
                          ),
                          subtitle: tr(
                            lang,
                            'Aniq vaqtda bo‘sh ustani o‘zingiz tanlaysiz',
                            'Вы выберете свободного мастера на точное время',
                            'Choose an available master for an exact time',
                          ),
                          selected: _option == 1,
                          onTap: () => setState(() => _option = 1),
                        ),
                      ],
                    ),
                  ),
                  if (_option == 1) ...[
                    const SizedBox(height: 14),
                    _appointmentCard(lang),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassButton(
              label: _option == 1 && _scheduledAt == null
                  ? tr(
                      lang,
                      'Sana va vaqtni tanlang',
                      'Выберите дату и время',
                      'Choose date and time',
                    )
                  : tr(lang, 'Davom etish', 'Продолжить', 'Continue'),
              height: 52,
              onPressed: canContinue ? _continue : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard(AppLanguage lang) {
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Kelish vaqti', 'Время визита', 'Visit time'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              lang,
              'Faqat shu vaqtda bo‘sh ustalarni ko‘rsatamiz',
              'Покажем только свободных в это время мастеров',
              'Only masters available at this time will be shown',
            ),
            style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 14),
          LiquidActionButton.text(
            onPressed: _pickAppointment,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _scheduledAt == null
                          ? tr(
                              lang,
                              'Sana va vaqtni tanlang',
                              'Выберите дату и время',
                              'Choose date and time',
                            )
                          : '${MaterialLocalizations.of(context).formatMediumDate(_scheduledAt!)}  ·  '
                                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_scheduledAt!), alwaysUse24HourFormat: true)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
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

class _TimingTile extends StatelessWidget {
  const _TimingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? .48 : 1,
      child: LiquidActionButton.text(
        onPressed: disabled ? null : onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF5FF)
                : Colors.white.withValues(alpha: .52),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.blue : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              LiquidSurface(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? AppColors.blue : const Color(0xFFE8EFF7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.navy,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.blue : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
