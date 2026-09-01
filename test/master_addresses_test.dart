import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_addresses_screen.dart';

class _FakeMasterAddressService extends MasterService {
  @override
  Future<Master> me() async => const Master(
    id: '#M-00000000001',
    phone: '+998900000000',
    status: MasterStatus.active,
    verificationStatus: VerificationStatus.approved,
    latitude: 41.30744,
    longitude: 69.29920,
    workRadiusKm: 10,
    baseLabel: 'IT Park University, Toshkent',
  );
}

void main() {
  testWidgets('master sees the saved work address under My addresses', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.uz;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);

    await tester.pumpWidget(
      MaterialApp(
        home: MasterAddressesScreen(service: _FakeMasterAddressService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mening manzillarim'), findsOneWidget);
    expect(find.text('IT Park University, Toshkent'), findsOneWidget);
    expect(find.textContaining('10 km ish radiusi'), findsOneWidget);
    expect(find.text('Manzilni o‘zgartirish'), findsOneWidget);
  });
}
