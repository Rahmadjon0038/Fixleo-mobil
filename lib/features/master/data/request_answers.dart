import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/categories/data/service_question.dart';

/// Immutable question snapshots: labels do not change when an admin edits a service.
class RequestAnswer {
  const RequestAnswer(this.question, this.value);
  final ServiceQuestion question;
  final Object? value;

  static List<RequestAnswer> parse(Object? json) => json is List
      ? json
            .whereType<Map<String, dynamic>>()
            .map((item) {
              return RequestAnswer(
                ServiceQuestion.fromJson({
                  ...item,
                  'id': item['questionId'] ?? '',
                  'required': false,
                  'options': item['options'] ?? [],
                }),
                item['value'],
              );
            })
            .toList(growable: false)
      : const [];

  String display(AppLanguage lang) => question.display(value, lang);

  String legacyDisplay(AppLanguage lang) =>
      question.type == 'datetime_picker' ? '$value' : display(lang);
}

/// Remove only the exact server-generated suffix, never split user prose on ':'.
String requestDescription(String description, List<RequestAnswer> answers) {
  var result = description.trim();
  if (answers.isEmpty) return result;
  for (final lang in AppLanguage.values) {
    final summary = answers
        .map((a) => '${a.question.label(lang)}: ${a.legacyDisplay(lang)}')
        .join('\n');
    if (result.endsWith('\n\n$summary')) {
      result = result.substring(0, result.length - summary.length).trim();
      break;
    }
  }
  // The questionnaire's free-text answer is also sent as the order description.
  if (answers.any(
    (a) => a.value is String && a.value.toString().trim() == result,
  )) {
    return '';
  }
  return result;
}
