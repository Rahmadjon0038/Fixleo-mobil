import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/auth/data/client_auth_service.dart';
import 'package:fixleo/features/auth/data/client_model.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_profile_tab_screen.dart';
import 'package:fixleo/features/profile/presentation/profile_screen.dart';
import 'package:fixleo/features/welcome/presentation/intro_screen.dart';

class _FakeClientAuthService extends ClientAuthService {
  int logoutCalls = 0;

  @override
  Future<Client> me() async => throw StateError('Profile is not needed here');

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

class _FakeMasterService extends MasterService {
  int logoutCalls = 0;

  @override
  Future<Master> me() async => throw StateError('Profile is not needed here');

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

void main() {
  setUp(() {
    LocaleController.language.value = AppLanguage.uz;
  });

  testWidgets('client delete account action only logs out', (tester) async {
    final service = _FakeClientAuthService();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(service: service)));
    await tester.pumpAndSettle();

    final deleteButton = find.text('Akkauntni o‘chirish');
    expect(deleteButton, findsOneWidget);
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(service.logoutCalls, 1);
    expect(find.byType(IntroScreen), findsOneWidget);
  });

  testWidgets('master delete account action only logs out', (tester) async {
    final service = _FakeMasterService();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MasterProfileTabScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    final deleteButton = find.text('Akkauntni o‘chirish');
    expect(deleteButton, findsOneWidget);
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(service.logoutCalls, 1);
    expect(find.byType(IntroScreen), findsOneWidget);
  });
}
