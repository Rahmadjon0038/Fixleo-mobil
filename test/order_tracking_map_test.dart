import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/features/request/data/order_models.dart';
import 'package:fixleo/features/request/data/order_service.dart';
import 'package:fixleo/features/request/presentation/order_tracking_screen.dart';

class _FakeOrderService extends OrderService {
  @override
  Future<OrderDetail> detail(int orderId) async => const OrderDetail(
    id: 1,
    title: 'Test service',
    description: 'Test description',
    status: 'searching',
    addressText: 'Tashkent',
    latitude: 41.311081,
    longitude: 69.279737,
    timing: 'today',
    slotLabel: '12:00–15:00',
  );
}

class _LiveOrderService extends OrderService {
  @override
  Future<OrderDetail> detail(int orderId) async => const OrderDetail(
    id: 1,
    title: 'Live service',
    description: 'Live test',
    status: 'on_the_way',
    addressText: 'Tashkent',
    latitude: 41.311081,
    longitude: 69.279737,
    timing: 'today',
  );

  @override
  Future<TrackInfo> track(int orderId) async => TrackInfo(
    status: 'on_the_way',
    lat: 41.302,
    lng: 69.265,
    accuracyMeters: 8,
    headingDegrees: 75,
    distanceKm: 1.7,
    etaMinutes: 4,
    at: DateTime.utc(2026, 9, 13, 9),
  );
}

void main() {
  test('order detail parses map coordinates from the backend payload', () {
    final order = OrderDetail.fromJson({
      'id': 1,
      'title': 'Test',
      'description': 'Description',
      'status': 'searching',
      'addressText': 'Tashkent',
      'latitude': 41.311081,
      'longitude': 69.279737,
    });

    expect(order.latitude, 41.311081);
    expect(order.longitude, 69.279737);
  });

  testWidgets('tracking shows a real map and the full status text', (
    tester,
  ) async {
    LocaleController.language.value = AppLanguage.en;
    addTearDown(() => LocaleController.language.value = AppLanguage.ru);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          orderId: 1,
          orderService: _FakeOrderService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GoogleMap), findsOneWidget);
    final status = tester.widget<Text>(find.text('Searching for a master'));
    expect(status.overflow, isNull);
    expect(status.maxLines, isNull);
  });

  testWidgets(
    'on-the-way tracking renders destination and live master markers',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: 1,
            orderService: _LiveOrderService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(
        map.markers.map((marker) => marker.markerId.value),
        containsAll(['order-destination', 'master-live-location']),
      );
      expect(map.circles.single.radius, 8);
    },
  );
}
