import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/profile/presentation/my_addresses_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';

class _FakeAddressService extends OrderService {
  @override
  Future<List<ClientAddress>> addresses() async => const [
    ClientAddress(
      id: 7,
      label: 'Home',
      addressText: 'Tashkent QA address',
      latitude: 41.31,
      longitude: 69.28,
      isDefault: true,
    ),
  ];
}

void main() {
  testWidgets('client address book shows backend addresses and add action', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);

    await tester.pumpWidget(
      MaterialApp(home: MyAddressesScreen(orderService: _FakeAddressService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tashkent QA address'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('New address'), findsOneWidget);
  });
}
