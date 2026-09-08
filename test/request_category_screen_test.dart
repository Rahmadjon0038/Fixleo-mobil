import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/categories/data/service_question.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';
import 'package:fixleo/features/request/presentation/request_category_screen.dart';

class _FakeCategoryService extends CategoryService {
  @override
  Future<List<CategoryGroup>> getGroups() async => const [
    CategoryGroup(
      id: 1,
      slug: 'home-repair',
      title: 'Home repair',
      titleUz: 'Uy ta’miri',
      titleRu: 'Ремонт дома',
      titleEn: 'Home repair',
      order: 0,
      isActive: true,
      services: [
        Category(id: 7, name: 'Plumbing', titleEn: 'Plumbing'),
        Category(id: 8, name: 'Electrical', titleEn: 'Electrical'),
      ],
    ),
  ];
}

class _NoQuestions extends ServiceQuestionService {
  @override
  Future<ServiceQuestionnaire> load(int categoryId) async =>
      const ServiceQuestionnaire(version: 0, questions: []);
}

void main() {
  testWidgets('search can receive focus immediately when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RequestCategoryScreen(
          service: _FakeCategoryService(),
          autofocusSearch: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);
  });

  testWidgets('request creation starts with a required category choice', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RequestCategoryScreen(
          service: _FakeCategoryService(),
          questionService: _NoQuestions(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a service'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('request-category-8')));
    await tester.pump();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final request = tester.widget<NewRequestScreen>(
      find.byType(NewRequestScreen),
    );
    expect(request.categoryId, 8);
    expect(request.categoryName, 'Electrical');
  });
}
