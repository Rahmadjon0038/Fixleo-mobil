import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/request/presentation/new_request_screen.dart';
import 'package:fixleo/features/request/presentation/request_category_screen.dart';

class _FakeCategoryService extends CategoryService {
  @override
  Future<List<Category>> getAll() async => const [
    Category(id: 7, name: 'Plumbing'),
    Category(id: 8, name: 'Electrical'),
  ];
}

void main() {
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
      MaterialApp(home: RequestCategoryScreen(service: _FakeCategoryService())),
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
