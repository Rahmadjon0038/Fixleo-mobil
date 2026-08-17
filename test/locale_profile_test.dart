import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/features/auth/presentation/phone_screen.dart';
import 'package:fixleo/features/language/presentation/language_screen.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_profile_tab_screen.dart';
import 'package:fixleo/features/welcome/presentation/role_select_screen.dart';

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
      expect(LocaleController.hasSavedLanguage, isTrue);
    },
  );

  testWidgets('saved language skips the language prompt after logout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_language': 'ru',
      'auth_role': 'client',
      'auth_access_token': 'access-token',
      'auth_refresh_token': 'refresh-token',
    });
    await LocaleController.load();
    await AuthSession.instance.load();
    await AuthSession.instance.clear();
    await LocaleController.load();

    await tester.pumpWidget(const MaterialApp(home: RoleSelectScreen()));
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(find.byType(LanguageScreen), findsNothing);
  });

  testWidgets('first install still asks for a language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocaleController.load();

    await tester.pumpWidget(const MaterialApp(home: RoleSelectScreen()));
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageScreen), findsOneWidget);
  });

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
