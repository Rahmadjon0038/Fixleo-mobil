import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/location/place_search_field.dart';
import 'package:fixleo/features/categories/data/service_question.dart';
import 'package:fixleo/features/request/presentation/service_questions_screen.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';

ServiceQuestion q(String id, String type, {bool required = true}) =>
    ServiceQuestion(
      id: id,
      type: type,
      required: required,
      uz: 'Question $id',
      ru: 'Question $id',
      en: 'Question $id',
      options: const [
        QuestionOption(id: 'a', uz: 'Option A', ru: 'Option A', en: 'Option A'),
        QuestionOption(id: 'b', uz: 'Option B', ru: 'Option B', en: 'Option B'),
      ],
    );

class FakeQuestions extends ServiceQuestionService {
  FakeQuestions(this.questions, {this.fail = false});
  final List<ServiceQuestion> questions;
  bool fail;
  @override
  Future<ServiceQuestionnaire> load(int categoryId) async {
    if (fail) throw StateError('network');
    return ServiceQuestionnaire(version: 4, questions: questions);
  }
}

void main() {
  setUp(() => LocaleController.language.value = AppLanguage.en);
  tearDown(() => LocaleController.language.value = AppLanguage.ru);
  Future<void> open(WidgetTester tester, FakeQuestions service) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ServiceQuestionsScreen(
                    categoryId: 7,
                    categoryName: 'Plumbing',
                    service: service,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('question-next')));
    await tester.pumpAndSettle();
  }

  testWidgets('required answers, multiple choice and back preserve values', (
    tester,
  ) async {
    await open(
      tester,
      FakeQuestions([q('one', 'multi_select'), q('two', 'toggle')]),
    );
    expect(find.text('Question 1 of 2'), findsOneWidget);
    await next(tester);
    expect(find.text('Please answer to continue.'), findsOneWidget);
    await tester.tap(find.text('Option A'));
    await tester.pump();
    await tester.tap(find.text('Option B'));
    await tester.pump();
    await next(tester);
    expect(find.text('Question 2 of 2'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(2));
    await next(tester);
    await tester.tap(find.text('No'));
    await tester.pump();
    await next(tester);
    final request = tester.widget<NewRequestScreen>(
      find.byType(NewRequestScreen),
    );
    expect(request.questionVersion, 4);
    expect(request.questionAnswers, [
      {
        'questionId': 'one',
        'value': ['a', 'b'],
      },
      {'questionId': 'two', 'value': false},
    ]);
  });
  testWidgets('exit confirms and cancellation retains entered text', (
    tester,
  ) async {
    await open(tester, FakeQuestions([q('one', 'textarea')]));
    await tester.enterText(
      find.byType(TextFormField),
      'Please repair the leaking tap.',
    );
    await tester.tap(find.byKey(const ValueKey('question-close')));
    await tester.pumpAndSettle();
    expect(find.text('Leave for now?'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('Please repair the leaking tap.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('question-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
  testWidgets('failed load blocks the flow and retry recovers', (tester) async {
    final service = FakeQuestions([q('one', 'radio')], fail: true);
    await open(tester, service);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const ValueKey('question-next')), findsNothing);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Option A'), findsOneWidget);
  });
  testWidgets('optional question can skip and checkbox supports false', (
    tester,
  ) async {
    await open(
      tester,
      FakeQuestions([
        q('one', 'select', required: false),
        q('two', 'checkbox'),
      ]),
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.tap(find.text('Skip this question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pump();
    await next(tester);
    final request = tester.widget<NewRequestScreen>(
      find.byType(NewRequestScreen),
    );
    expect(request.questionAnswers, [
      {'questionId': 'two', 'value': false},
    ]);
  });
  testWidgets('address search and date picker render; optional skip works', (
    tester,
  ) async {
    await open(
      tester,
      FakeQuestions([
        q('one', 'address_autocomplete', required: false),
        q('two', 'datetime_picker', required: false),
      ]),
    );
    expect(find.byType(PlaceSearchField), findsOneWidget);
    await tester.tap(find.text('Skip this question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose date and time'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this question'));
    await tester.pumpAndSettle();
    expect(find.byType(NewRequestScreen), findsOneWidget);
  });
  testWidgets('service without questions opens existing request screen', (
    tester,
  ) async {
    await open(tester, FakeQuestions([]));
    expect(find.byType(NewRequestScreen), findsOneWidget);
    expect(find.byType(ServiceQuestionsScreen), findsNothing);
  });
}
