import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_client.dart';

class QuestionOption {
  const QuestionOption({
    required this.id,
    required this.uz,
    required this.ru,
    required this.en,
  });
  factory QuestionOption.fromJson(Map<String, dynamic> j) => QuestionOption(
    id: j['id'] as String,
    uz: j['labelUz'] as String,
    ru: j['labelRu'] as String,
    en: j['labelEn'] as String,
  );
  final String id, uz, ru, en;
  String label(AppLanguage lang) => tr(lang, uz, ru, en);
}

class ServiceQuestion extends QuestionOption {
  const ServiceQuestion({
    required super.id,
    required super.uz,
    required super.ru,
    required super.en,
    required this.type,
    required this.required,
    this.options = const [],
  });
  factory ServiceQuestion.fromJson(Map<String, dynamic> j) => ServiceQuestion(
    id: j['id'] as String,
    uz: j['labelUz'] as String,
    ru: j['labelRu'] as String,
    en: j['labelEn'] as String,
    type: j['type'] as String,
    required: j['required'] as bool,
    options: (j['options'] as List)
        .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
        .toList(),
  );
  final String type;
  final bool required;
  final List<QuestionOption> options;
  bool isAnswered(Object? value) =>
      value != null &&
      (value is! String || value.trim().isNotEmpty) &&
      (value is! List || value.isNotEmpty);
  String display(Object? value, AppLanguage lang) {
    if (type == 'datetime_picker' && value is String) {
      final date = DateTime.tryParse(value)?.toLocal();
      if (date != null) {
        String two(int n) => n.toString().padLeft(2, '0');
        return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
      }
    }
    String option(Object? v) =>
        options.where((o) => o.id == v).firstOrNull?.label(lang) ?? '$v';
    if (value is bool) {
      return value
          ? tr(lang, 'Ha', 'Да', 'Yes')
          : tr(lang, 'Yo‘q', 'Нет', 'No');
    }
    if (value is List) return value.map(option).join(', ');
    if (value is Map) return value['addressText'] as String? ?? '';
    return value == null ? '' : option(value);
  }
}

class ServiceQuestionnaire {
  const ServiceQuestionnaire({required this.version, required this.questions});
  factory ServiceQuestionnaire.fromJson(Map<String, dynamic> j) =>
      ServiceQuestionnaire(
        version: j['version'] as int,
        questions: (j['questions'] as List)
            .map((q) => ServiceQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
  final int version;
  final List<ServiceQuestion> questions;
}

class ServiceQuestionService {
  ServiceQuestionService({ApiClient? client})
    : _client = client ?? ApiClient.instance;
  final ApiClient _client;
  Future<ServiceQuestionnaire> load(int categoryId) async =>
      ServiceQuestionnaire.fromJson(
        await _client.get('/categories/$categoryId/questions')
            as Map<String, dynamic>,
      );
}
