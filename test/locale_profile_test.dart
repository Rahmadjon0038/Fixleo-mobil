import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_profile_tab_screen.dart';

class _FakeMasterService extends MasterService {
  @override
  Future<Master> me() async => throw StateError('Profile is not needed here');
}

void main() {
  test(
    'saved language is restored instead of being forced back to Russian',
    () async {
      SharedPreferences.setMockInitialValues({'app_language': 'uz'});
      LocaleController.language.value = AppLanguage.ru;

      await LocaleController.load();

      expect(LocaleController.language.value, AppLanguage.uz);
    },
  );

  testWidgets(
    'master language radio rebuilds immediately after selecting Uzbek',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      LocaleController.language.value = AppLanguage.ru;
      addTearDown(() => LocaleController.language.value = AppLanguage.ru);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasterProfileTabScreen(service: _FakeMasterService()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Узбекский'), findsOneWidget);
      await tester.tap(find.text('Узбекский'));
      await tester.pump();

      expect(LocaleController.language.value, AppLanguage.uz);
      expect(find.text('O‘zbekcha'), findsOneWidget);
      expect(find.text('Til'), findsOneWidget);

      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('O‘zbekcha'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
    },
  );
}
