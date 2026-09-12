import 'package:flutter/material.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/features/master/data/request_answers.dart';

class RequestAnswersSection extends StatelessWidget {
  const RequestAnswersSection({super.key, required this.answers});
  final List<RequestAnswer> answers;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(lang, 'Buyurtma tafsilotlari', 'Детали заявки', 'Request details'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr(lang, 'Mijozning javoblari', 'Ответы клиента', 'Client answers'),
          style: const TextStyle(fontSize: 13, color: Color(0xFF69788F)),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < answers.length; i++) ...[
          GlassContainer.lite(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiquidSurface(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        answers[i].question.label(lang),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF69788F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (answers[i].value is List)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in answers[i].value as List)
                        LiquidSurface(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F6FC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            answers[i].question.display(value, lang),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    answers[i].display(lang),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
              ],
            ),
          ),
          if (i != answers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
