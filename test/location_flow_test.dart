import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/location/device_location_service.dart';
import 'package:fixleo/core/location/reverse_geocoder.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/address_screen.dart';
import 'package:fixleo/features/work_radius/data/work_radius_model.dart';
import 'package:fixleo/features/work_radius/data/work_radius_service.dart';

class _FakeLocationService extends DeviceLocationService {
  _FakeLocationService({this.error});

  final LatLng point = const LatLng(41.2995, 69.2401);
  final DeviceLocationException? error;
  int locationCalls = 0;
  int appSettingsCalls = 0;

  @override
  Future<LatLng> currentLocation() async {
    locationCalls++;
    if (error != null) throw error!;
    return point;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }
}

class _FakeReverseGeocoder extends ReverseGeocoder {
  @override
  Future<ReverseGeocodeResult?> resolve(LatLng point) async {
    if (point.latitude == 41.2995 && point.longitude == 69.2401) {
      return const ReverseGeocodeResult(
        label: 'Current GPS location',
        subtitle: 'Test street',
      );
    }
    return const ReverseGeocodeResult(
      label: 'Saved location',
      subtitle: 'Old street',
    );
  }
}

class _FakeWorkRadiusService extends WorkRadiusService {
  @override
  Future<List<WorkRadius>> getOptions() async => const [];
}

class _FakeOrderService extends OrderService {
  int saveCalls = 0;
  double? savedLatitude;
  double? savedLongitude;

  @override
  Future<ClientAddress> saveAddress({
    int? id,
    required String addressText,
    String? district,
    required double latitude,
    required double longitude,
    String? details,
    bool isDefault = true,
  }) async {
    saveCalls++;
    savedLatitude = latitude;
    savedLongitude = longitude;
    return ClientAddress(
      id: id ?? 99,
      addressText: addressText,
      latitude: latitude,
      longitude: longitude,
      details: details,
      isDefault: isDefault,
    );
  }
}

const _savedAddress = ClientAddress(
  id: 7,
  addressText: 'Saved address',
  latitude: 41.311081,
  longitude: 69.279737,
);

void main() {
  setUp(() {
    LocaleController.language.value = AppLanguage.en;
  });

  tearDown(() {
    LocaleController.language.value = AppLanguage.ru;
  });

  testWidgets('new address flow asks for and centers on device location', (
    tester,
  ) async {
    final location = _FakeLocationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AddressScreen(
          isOnboarding: true,
          locationService: location,
          geocoder: _FakeReverseGeocoder(),
          loadMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(location.locationCalls, 1);
    expect(find.text('Current GPS location'), findsOneWidget);
    expect(find.text('Test street'), findsOneWidget);
  });

  testWidgets('my-location button moves an existing address to device GPS', (
    tester,
  ) async {
    final location = _FakeLocationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AddressScreen(
          isEditingHome: true,
          initialAddress: _savedAddress,
          locationService: location,
          geocoder: _FakeReverseGeocoder(),
          loadMapTiles: false,
        ),
      ),
    );
    await tester.pump();

    expect(location.locationCalls, 0);
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(location.locationCalls, 1);
    expect(find.text('Current GPS location'), findsOneWidget);
  });

  testWidgets('master work zone starts at the device location', (tester) async {
    final location = _FakeLocationService();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MasterWorkZoneScreen(
          locationService: location,
          geocoder: _FakeReverseGeocoder(),
          workRadiusService: _FakeWorkRadiusService(),
          loadMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(location.locationCalls, 1);
    expect(find.text('Current GPS location'), findsOneWidget);
  });

  testWidgets('an address anywhere in the world can be saved', (tester) async {
    final orders = _FakeOrderService();
    const london = ClientAddress(
      id: 8,
      addressText: 'London',
      latitude: 51.5074,
      longitude: -0.1278,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddressScreen(
          isEditingHome: true,
          initialAddress: london,
          orderService: orders,
          geocoder: _FakeReverseGeocoder(),
          loadMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(orders.saveCalls, 1);
    expect(orders.savedLatitude, london.latitude);
    expect(orders.savedLongitude, london.longitude);
  });

  testWidgets('permanently denied permission offers app settings', (
    tester,
  ) async {
    final location = _FakeLocationService(
      error: const DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddressScreen(
          isEditingHome: true,
          initialAddress: _savedAddress,
          locationService: location,
          geocoder: _FakeReverseGeocoder(),
          loadMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();

    expect(
      find.text('Location permission is blocked. Enable it in Settings'),
      findsOneWidget,
    );
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();

    expect(location.appSettingsCalls, 1);
  });
}
