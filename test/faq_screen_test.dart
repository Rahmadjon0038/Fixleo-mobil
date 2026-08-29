import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/faq/data/faq_model.dart';
import 'package:fixleo/features/faq/data/faq_service.dart';
import 'package:fixleo/features/faq/presentation/faq_screen.dart';

class _FakeFaqService extends FaqService {
  String? requestedAudience;

  @override
  Future<List<FaqItem>> list({required String audience}) async {
    requestedAudience = audience;
    return const [
      FaqItem(
        id: 1,
        audience: 'client',
        topic: 'Buyurtma',
        topicUz: 'Buyurtma',
        topicRu: 'Заказ',
        topicEn: 'Order',
        question: 'Buyurtmani qanday bekor qilaman?',
        questionUz: 'Buyurtmani qanday bekor qilaman?',
        questionRu: 'Как отменить заказ?',
        questionEn: 'How do I cancel an order?',
        answer: '**Buyurtmalar** bo‘limidan bekor qiling.',
        answerUz: '**Buyurtmalar** bo‘limidan bekor qiling.',
        answerRu: 'Отмените в разделе **Заказы**.',
        answerEn: 'Cancel it from **Orders**.',
        order: 10,
      ),
      FaqItem(
        id: 2,
        audience: 'both',
        topic: 'Xavfsizlik',
        topicUz: 'Xavfsizlik',
        topicRu: 'Безопасность',
        topicEn: 'Safety',
        question: 'Chat xavfsizmi?',
        questionUz: 'Chat xavfsizmi?',
        questionRu: 'Чат безопасен?',
        questionEn: 'Is chat safe?',
        answer: 'Ha.',
        answerUz: 'Ha.',
        answerRu: 'Да.',
        answerEn: 'Yes.',
        order: 20,
      ),
    ];
  }
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.uz);

  testWidgets('FAQ loads for its role, localizes and filters while typing', (
    tester,
  ) async {
    final service = _FakeFaqService();
    await tester.pumpWidget(
      MaterialApp(
        home: FaqScreen(audience: 'client', service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.requestedAudience, 'client');
    expect(find.text('Buyurtmani qanday bekor qilaman?'), findsOneWidget);
    expect(find.text('Chat xavfsizmi?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'chat');
    await tester.pump();

    expect(find.text('Buyurtmani qanday bekor qilaman?'), findsNothing);
    expect(find.text('Chat xavfsizmi?'), findsOneWidget);
  });
}
