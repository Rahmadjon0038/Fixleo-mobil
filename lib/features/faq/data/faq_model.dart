import 'package:fixleo/app/locale/app_locale.dart';

class FaqItem {
  const FaqItem({
    required this.id,
    required this.audience,
    required this.topic,
    required this.topicUz,
    required this.topicRu,
    required this.topicEn,
    required this.question,
    required this.questionUz,
    required this.questionRu,
    required this.questionEn,
    required this.answer,
    required this.answerUz,
    required this.answerRu,
    required this.answerEn,
    required this.order,
  });

  final int id;
  final String audience;
  final String topic;
  final String topicUz;
  final String topicRu;
  final String topicEn;
  final String question;
  final String questionUz;
  final String questionRu;
  final String questionEn;
  final String answer;
  final String answerUz;
  final String answerRu;
  final String answerEn;
  final int order;

  String localizedTopic(AppLanguage language) => switch (language) {
    AppLanguage.uz => topicUz.isNotEmpty ? topicUz : topic,
    AppLanguage.ru => topicRu.isNotEmpty ? topicRu : topic,
    AppLanguage.en => topicEn.isNotEmpty ? topicEn : topic,
  };

  String localizedQuestion(AppLanguage language) => switch (language) {
    AppLanguage.uz => questionUz.isNotEmpty ? questionUz : question,
    AppLanguage.ru => questionRu.isNotEmpty ? questionRu : question,
    AppLanguage.en => questionEn.isNotEmpty ? questionEn : question,
  };

  String localizedAnswer(AppLanguage language) => switch (language) {
    AppLanguage.uz => answerUz.isNotEmpty ? answerUz : answer,
    AppLanguage.ru => answerRu.isNotEmpty ? answerRu : answer,
    AppLanguage.en => answerEn.isNotEmpty ? answerEn : answer,
  };

  bool matches(String query, AppLanguage language) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      localizedTopic(language),
      localizedQuestion(language),
      localizedAnswer(language),
    ].join(' ').toLowerCase().contains(needle);
  }

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
    id: (json['id'] as num).toInt(),
    audience: json['audience'] as String? ?? 'both',
    topic: json['topic'] as String? ?? '',
    topicUz: json['topicUz'] as String? ?? '',
    topicRu: json['topicRu'] as String? ?? '',
    topicEn: json['topicEn'] as String? ?? '',
    question: json['question'] as String? ?? '',
    questionUz: json['questionUz'] as String? ?? '',
    questionRu: json['questionRu'] as String? ?? '',
    questionEn: json['questionEn'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
    answerUz: json['answerUz'] as String? ?? '',
    answerRu: json['answerRu'] as String? ?? '',
    answerEn: json['answerEn'] as String? ?? '',
    order: (json['order'] as num?)?.toInt() ?? 0,
  );
}
