import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:flutter/material.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/core/location/place_search_field.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/categories/data/service_question.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';

/// A versioned, server-defined questionnaire. Values stay here while navigating
/// back/forward; submitting an order always validates against the server schema.
class ServiceQuestionsScreen extends StatefulWidget {
  const ServiceQuestionsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.service,
  });
  final int categoryId;
  final String categoryName;
  final ServiceQuestionService? service;
  @override
  State<ServiceQuestionsScreen> createState() => _ServiceQuestionsScreenState();
}

class _ServiceQuestionsScreenState extends State<ServiceQuestionsScreen> {
  final Map<String, Object> _answers = {};
  ServiceQuestionnaire? _schema;
  int _step = 0;
  bool _loading = true, _leaving = false, _confirmingExit = false;
  String? _error, _validation;
  final _scroll = ScrollController();
  AppLanguage get _lang => LocaleController.language.value;
  String _t(String uz, String ru, String en) => tr(_lang, uz, ru, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schema = await (widget.service ?? ServiceQuestionService()).load(
        widget.categoryId,
      );
      if (!mounted) return;
      setState(() {
        _schema = schema;
        _loading = false;
      });
      if (schema.questions.isEmpty) _continueToRequest(replace: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException
              ? e.message
              : _t(
                  'Savollarni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
                  'Не удалось загрузить вопросы. Попробуйте ещё раз.',
                  'Could not load questions. Please try again.',
                );
        });
      }
    }
  }

  Future<void> _exit() async {
    if (_confirmingExit || _leaving) return;
    _confirmingExit = true;
    final leave =
        _answers.isEmpty ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(
                  _t(
                    'Hozircha to‘xtatasizmi?',
                    'Прервать заполнение?',
                    'Leave for now?',
                  ),
                ),
                content: Text(
                  _t(
                    'Bu buyurtma hali yuborilmagan. Chiqsangiz, kiritilgan javoblar bekor bo‘ladi.',
                    'Заявка ещё не отправлена. При выходе ответы будут удалены.',
                    'Your request has not been sent. Leaving will discard these answers.',
                  ),
                ),
                actions: [
                  LiquidActionButton.text(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(_t('Davom etish', 'Продолжить', 'Keep going')),
                  ),
                  LiquidActionButton.text(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(_t('Chiqish', 'Выйти', 'Leave')),
                  ),
                ],
              ),
            ) ==
            true;
    _confirmingExit = false;
    if (leave && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _back() {
    if (_step > 0) {
      _go(_step - 1);
    } else {
      _exit();
    }
  }

  void _go(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = index;
      _validation = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _answer(ServiceQuestion q, Object value) => setState(() {
    _answers[q.id] = value;
    _validation = null;
  });
  void _next({bool skip = false}) {
    final q = _schema!.questions[_step];
    if (skip) _answers.remove(q.id);
    if (q.required && !q.isAnswered(_answers[q.id])) {
      setState(
        () => _validation = _t(
          'Davom etish uchun javobni kiriting.',
          'Ответьте, чтобы продолжить.',
          'Please answer to continue.',
        ),
      );
      return;
    }
    if (_step + 1 == _schema!.questions.length) {
      _continueToRequest();
    } else {
      _go(_step + 1);
    }
  }

  void _continueToRequest({bool replace = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    final schema = _schema!;
    final completed = schema.questions
        .where((q) => q.isAnswered(_answers[q.id]))
        .toList();
    final details = completed.where((q) => q.type == 'textarea').firstOrNull;
    final route = MaterialPageRoute<void>(
      builder: (_) => NewRequestScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        questionVersion: schema.version,
        questionAnswers: completed
            .map(
              (q) => <String, dynamic>{
                'questionId': q.id,
                'value': _answers[q.id],
              },
            )
            .toList(),
        questionSummary: completed
            .map(
              (q) => '${q.label(_lang)}: ${q.display(_answers[q.id], _lang)}',
            )
            .join('\n\n'),
        initialDescription: details == null
            ? ''
            : _answers[details.id] as String,
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _schema?.questions ?? [];
    final q = questions.isEmpty ? null : questions[_step];
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: LiquidAppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: LiquidIconControl(
            child: IconButton(
              key: const ValueKey('question-back'),
              onPressed: _back,
              tooltip: _t('Orqaga', 'Назад', 'Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          title: Text(
            widget.categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            LiquidIconControl(
              child: IconButton(
                key: const ValueKey('question-close'),
                onPressed: _exit,
                tooltip: _t('To‘xtatish', 'Закрыть', 'Close'),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        LiquidActionButton.filled(
                          onPressed: _load,
                          child: Text(
                            _t('Qayta urinish', 'Повторить', 'Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : q == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _t(
                                  '${_step + 1} / ${questions.length} savol',
                                  'Вопрос ${_step + 1} из ${questions.length}',
                                  'Question ${_step + 1} of ${questions.length}',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blue,
                                ),
                              ),
                              Text(
                                _step + 1 == questions.length
                                    ? _t(
                                        'Oxirgi savol',
                                        'Последний вопрос',
                                        'Last question',
                                      )
                                    : _t(
                                        'Yana ${questions.length - _step - 1} ta',
                                        'Осталось ${questions.length - _step - 1}',
                                        '${questions.length - _step - 1} left',
                                      ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: (_step + 1) / questions.length),
                            duration: const Duration(milliseconds: 220),
                            builder: (_, value, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFEAF0F5),
                                color: AppColors.blue,
                                semanticsLabel: _t(
                                  'Savollar jarayoni',
                                  'Прогресс',
                                  'Progress',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          key: ValueKey(q.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.required
                                  ? _t(
                                      'MAJBURIY SAVOL',
                                      'ОБЯЗАТЕЛЬНЫЙ ВОПРОС',
                                      'REQUIRED',
                                    )
                                  : _t(
                                      'IXTIYORIY SAVOL',
                                      'НЕОБЯЗАТЕЛЬНЫЙ ВОПРОС',
                                      'OPTIONAL',
                                    ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              q.label(_lang),
                              style: const TextStyle(
                                fontSize: 25,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hint(q),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _input(q),
                            if (_validation != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _validation!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    LiquidSurface(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFEDF1F5)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LiquidActionButton.filled(
                            key: const ValueKey('question-next'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 17),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _next,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _step + 1 == questions.length
                                      ? _t(
                                          'Keyingi bosqich',
                                          'Следующий этап',
                                          'Next stage',
                                        )
                                      : _t(
                                          'Davom etish',
                                          'Продолжить',
                                          'Continue',
                                        ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          if (!q.required)
                            LiquidActionButton.text(
                              onPressed: () => _next(skip: true),
                              child: Text(
                                _t(
                                  'Bu savolni o‘tkazib yuborish',
                                  'Пропустить вопрос',
                                  'Skip this question',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _hint(ServiceQuestion q) => switch (q.type) {
    'multi_select' => _t(
      'Mos kelgan barcha variantlarni belgilang.',
      'Выберите все подходящие варианты.',
      'Select all that apply.',
    ),
    'textarea' => _t(
      'Tafsilotlar ustaga vazifani yaxshiroq tushunishga yordam beradi.',
      'Детали помогут мастеру лучше понять задачу.',
      'Details help your professional understand the task.',
    ),
    'address_autocomplete' => _t(
      'Manzilni yozing va topilgan natijadan tanlang.',
      'Введите адрес и выберите результат.',
      'Type an address and choose a result.',
    ),
    'datetime_picker' => _t(
      'Sizga qulay sana va vaqtni tanlang.',
      'Выберите удобную дату и время.',
      'Choose a suitable date and time.',
    ),
    _ => _t(
      'Sizga mos javobni tanlang.',
      'Выберите подходящий ответ.',
      'Choose the answer that fits.',
    ),
  };

  Widget _card(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool multiple = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LiquidMaterial(
      color: selected ? const Color(0xFFF0F7FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: LiquidSurface(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.blue : const Color(0xFFDDE4ED),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                multiple
                    ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                    : (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                color: selected ? AppColors.blue : AppColors.muted,
                size: 23,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _input(ServiceQuestion q) {
    final value = _answers[q.id];
    switch (q.type) {
      case 'radio':
        return Column(
          children: q.options
              .map(
                (o) => _card(
                  o.label(_lang),
                  value == o.id,
                  () => _answer(q, o.id),
                ),
              )
              .toList(),
        );
      case 'select':
        return DropdownButtonFormField<String>(
          initialValue: value as String?,
          isExpanded: true,
          decoration: _decoration(
            _t('Variantni tanlang', 'Выберите вариант', 'Choose an option'),
          ),
          items: q.options
              .map(
                (o) => DropdownMenuItem(
                  value: o.id,
                  child: Text(
                    o.label(_lang),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) _answer(q, v);
          },
        );
      case 'multi_select':
        final selected = (value as List<String>?) ?? <String>[];
        return Column(
          children: q.options
              .map(
                (o) => _card(o.label(_lang), selected.contains(o.id), () {
                  final next = [...selected];
                  if (!next.remove(o.id)) next.add(o.id);
                  _answer(q, next);
                }, multiple: true),
              )
              .toList(),
        );
      case 'textarea':
        return TextFormField(
          initialValue: value as String? ?? '',
          minLines: 5,
          maxLines: 9,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => _answer(q, v),
          decoration: _decoration(
            _t('Javobingizni yozing…', 'Напишите ответ…', 'Write your answer…'),
          ),
        );
      case 'toggle':
        return Column(
          children: [
            _card(_t('Ha', 'Да', 'Yes'), value == true, () => _answer(q, true)),
            _card(
              _t('Yo‘q', 'Нет', 'No'),
              value == false,
              () => _answer(q, false),
            ),
          ],
        );
      case 'checkbox':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
              _t('Ha, tasdiqlayman', 'Да, подтверждаю', 'Yes, I confirm'),
              value == true,
              () => _answer(q, value != true),
              multiple: true,
            ),
            LiquidActionButton.text(
              onPressed: () => _answer(q, false),
              child: Text(
                value == false
                    ? _t('Javob: Yo‘q', 'Ответ: Нет', 'Answer: No')
                    : _t('Yo‘q', 'Нет', 'No'),
              ),
            ),
          ],
        );
      case 'address_autocomplete':
        if (value is Map) {
          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.blue,
                ),
                title: Text(value['addressText'] as String),
              ),
              LiquidActionButton.text(
                onPressed: () => setState(() => _answers.remove(q.id)),
                child: Text(
                  _t(
                    'Manzilni o‘zgartirish',
                    'Изменить адрес',
                    'Change address',
                  ),
                ),
              ),
            ],
          );
        }
        return PlaceSearchField(
          language: _lang,
          onSelected: (p) => _answer(q, <String, dynamic>{
            'addressText': [
              p.label,
              p.subtitle,
            ].where((s) => s.isNotEmpty).join(', '),
            'latitude': p.point.latitude,
            'longitude': p.point.longitude,
          }),
        );
      case 'datetime_picker':
        final date = value is String
            ? DateTime.tryParse(value)?.toLocal()
            : null;
        return LiquidActionButton.outlinedIcon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () async {
            final now = DateTime.now();
            final day = await showDatePicker(
              context: context,
              initialDate: date != null && date.isAfter(now) ? date : now,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 2, now.month, now.day),
            );
            if (day == null || !mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: date == null
                  ? TimeOfDay.now()
                  : TimeOfDay.fromDateTime(date),
            );
            if (time != null && mounted) {
              _answer(
                q,
                DateTime(
                  day.year,
                  day.month,
                  day.day,
                  time.hour,
                  time.minute,
                ).toUtc().toIso8601String(),
              );
            }
          },
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(
            date == null
                ? _t(
                    'Sana va vaqtni tanlash',
                    'Выбрать дату и время',
                    'Choose date and time',
                  )
                : '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}',
          ),
        );
      default:
        return Text(
          _t(
            'Bu savol uchun ilovani yangilang.',
            'Обновите приложение для этого вопроса.',
            'Update the app to answer this question.',
          ),
        );
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.all(18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDDE4ED)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDDE4ED)),
    ),
  );
}
