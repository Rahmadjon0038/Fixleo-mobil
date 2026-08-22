import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/categories/data/category_model.dart';
import 'package:fixleo/features/categories/data/category_service.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_categories_screen.dart';

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
        Category(
          id: 7,
          name: 'Plumbing',
          titleEn: 'Plumbing',
          tags: ['faucet', 'pipe'],
        ),
        Category(
          id: 8,
          name: 'Electrical',
          titleEn: 'Electrical',
          tags: ['wiring', 'outlet'],
        ),
      ],
    ),
  ];
}

class _FakeMasterService extends MasterService {
  @override
  Future<Master> me() async => const Master(
    id: '#M-1',
    phone: '+998900000000',
    status: MasterStatus.unverified,
    verificationStatus: VerificationStatus.notSubmitted,
    categories: [Category(id: 7, name: 'Plumbing', titleEn: 'Plumbing')],
  );
}

void main() {
  testWidgets(
    'master sees grouped searchable services and existing selection',
    (tester) async {
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
          home: MasterCategoriesScreen(
            categoryService: _FakeCategoryService(),
            masterService: _FakeMasterService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home repair'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Electrical'), findsOneWidget);
      expect(find.text('Continue · 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'outlet');
      await tester.pump();

      expect(find.text('Plumbing'), findsNothing);
      expect(find.text('Electrical'), findsOneWidget);

      await tester.tap(find.text('Electrical'));
      await tester.pump();
      expect(find.text('Continue · 2'), findsOneWidget);
    },
  );
}
