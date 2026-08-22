import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/profile/presentation/my_addresses_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';

class _FakeAddressService extends OrderService {
  int? selectedId;

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
    ClientAddress(
      id: 8,
      label: 'Office',
      addressText: 'Tashkent office address',
      latitude: 41.32,
      longitude: 69.29,
    ),
  ];

  @override
  Future<ClientAddress> saveAddress({
    int? id,
    String? label,
    required String addressText,
    String? district,
    required double latitude,
    required double longitude,
    String? details,
    bool isDefault = true,
  }) async {
    selectedId = id;
    return ClientAddress(
      id: id ?? 99,
      label: label,
      addressText: addressText,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }
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

  testWidgets('location picker selects a saved address and returns it', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    final service = _FakeAddressService();

    await tester.pumpWidget(
      MaterialApp(home: _AddressPickerHost(service: service)),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('Choose an address'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('New address'), findsOneWidget);

    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();

    expect(service.selectedId, 8);
    expect(find.text('Selected: Office'), findsOneWidget);
  });
}

class _AddressPickerHost extends StatefulWidget {
  const _AddressPickerHost({required this.service});

  final _FakeAddressService service;

  @override
  State<_AddressPickerHost> createState() => _AddressPickerHostState();
}

class _AddressPickerHostState extends State<_AddressPickerHost> {
  ClientAddress? _selected;

  Future<void> _open() async {
    final selected = await Navigator.of(context).push<ClientAddress>(
      MaterialPageRoute(
        builder: (_) => MyAddressesScreen(
          orderService: widget.service,
          selectionMode: true,
          selectedAddressId: 7,
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: _open,
          child: Text(
            _selected == null ? 'Open picker' : 'Selected: ${_selected!.label}',
          ),
        ),
      ),
    );
  }
}
