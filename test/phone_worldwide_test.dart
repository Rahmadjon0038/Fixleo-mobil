import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/auth/presentation/phone_screen.dart';

void main() {
  setUp(() {
    LocaleController.language.value = AppLanguage.en;
  });

  tearDown(() {
    LocaleController.language.value = AppLanguage.ru;
  });

  testWidgets('other country accepts any valid E.164 number', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PhoneScreen()));
    await tester.tap(find.text('Uzb'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other country'));
    await tester.pumpAndSettle();

    final getCode = find.widgetWithText(PrimaryButton, 'Get code');
    await tester.enterText(find.byType(TextField), '12025550123');
    await tester.pump();

    expect(find.text('+'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(getCode).onPressed, isNotNull);
  });
}
