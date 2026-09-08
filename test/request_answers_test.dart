import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/master/data/master_marketplace_models.dart';
import 'package:fixleo/features/master/data/master_marketplace_service.dart';
import 'package:fixleo/features/master/data/request_answers.dart';
import 'package:fixleo/features/master/presentation/master_request_detail_screen.dart';

Map<String, dynamic> answer(String type, Object value) => {
  'questionId': type,
  'type': type,
  'labelUz': 'Savol $type?',
  'labelRu': 'Вопрос $type?',
  'labelEn': 'Question $type?',
  'options': [
    {
      'id': 'a',
      'labelUz': 'Lift bor',
      'labelRu': 'Есть лифт',
      'labelEn': 'Elevator',
    },
  ],
  'value': value,
};

class FakeMarket extends MasterMarketplaceService {
  @override
  Future<FeedDetail> feedDetail(int orderId) async => FeedDetail(
    id: orderId,
    categoryName: 'Maysa va bog‘ parvarishi',
    description: '',
    addressText: 'Toshkent',
    answers: RequestAnswer.parse([
      answer('textarea', List.filled(20, 'Batafsil ma’lumot').join('\n')),
      answer('multi_select', ['a']),
      answer('datetime_picker', '2026-09-17T04:52:00.000Z'),
      answer('checkbox', true),
    ]),
  );
}

void main() {
  test(
    'removes exact legacy suffix and duplicate description, not free prose',
    () {
      final answers = RequestAnswer.parse([answer('textarea', 'Ish kerak')]);
      expect(
        requestDescription('Ish kerak\n\nSavol textarea?: Ish kerak', answers),
        '',
      );
      expect(
        requestDescription('Izoh: qo‘ng‘iroq qiling', answers),
        'Izoh: qo‘ng‘iroq qiling',
      );
      expect(requestDescription('A\n\nB', []), 'A\n\nB');
    },
  );
  test('formats choice, boolean and date snapshots in all languages', () {
    final answers = RequestAnswer.parse([
      answer('multi_select', ['a']),
      answer('checkbox', false),
      answer('datetime_picker', '2026-09-17T04:52:00.000Z'),
    ]);
    expect(answers[0].display(AppLanguage.ru), 'Есть лифт');
    expect(answers[1].display(AppLanguage.en), 'No');
    expect(answers[1].display(AppLanguage.uz), 'Yo‘q');
    expect(answers[2].display(AppLanguage.uz), contains('17.09.2026'));
    expect(answers[2].display(AppLanguage.uz), isNot(contains('T04:')));
  });
  test('old backend without snapshots remains readable', () {
    final detail = FeedDetail.fromJson({
      'id': 1,
      'description': 'Eski buyurtma',
    });
    expect(detail.answers, isEmpty);
    expect(detail.summary, 'Eski buyurtma');
  });
  for (final lang in AppLanguage.values) {
    testWidgets('long request scrolls, CTA stays visible at 320px in $lang', (
      tester,
    ) async {
      LocaleController.language.value = lang;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MasterRequestDetailScreen(orderId: 15, service: FakeMarket()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final respond = find.text(
        tr(lang, 'Javob berish', 'Откликнуться', 'Respond'),
      );
      final initialPosition = tester.getTopLeft(respond);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1400),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(respond), initialPosition);
      expect(find.text(tr(lang, 'Ha', 'Да', 'Yes')), findsOneWidget);
    });
  }
}
