import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/core/location/navigation_launcher.dart';
import 'package:fixleo/core/realtime/app_presence_service.dart';
import 'package:fixleo/features/request/data/order_models.dart';

void main() {
  test('builds external navigator links for the order destination', () {
    const launcher = NavigationLauncher();

    final google = launcher.googleMapsUrl(
      latitude: 41.311081,
      longitude: 69.279737,
    );
    final yandex = launcher.yandexNavigatorUrl(
      latitude: 41.311081,
      longitude: 69.279737,
    );

    expect(google.host, 'www.google.com');
    expect(google.queryParameters['destination'], '41.311081,69.279737');
    expect(google.queryParameters['travelmode'], 'driving');
    expect(yandex.scheme, 'yandexnavi');
    expect(yandex.queryParameters['lat_to'], '41.311081');
    expect(yandex.queryParameters['lon_to'], '69.279737');
  });

  test('parses the same live location contract from REST and realtime', () {
    const payload = {
      'orderId': 45,
      'latitude': 41.302,
      'longitude': 69.265,
      'accuracyMeters': 6.5,
      'headingDegrees': 125,
      'speedMps': 8,
      'distanceKm': 1.73,
      'etaMinutes': 4,
      'at': '2026-09-13T09:00:00.000Z',
    };

    final realtime = MasterLocationUpdate.fromJson(payload);
    final rest = TrackInfo.fromJson({
      'status': 'on_the_way',
      'masterLocation': payload,
      'distanceKm': payload['distanceKm'],
      'etaMinutes': payload['etaMinutes'],
    });

    expect(realtime.orderId, 45);
    expect(realtime.latitude, rest.lat);
    expect(realtime.longitude, rest.lng);
    expect(realtime.accuracyMeters, rest.accuracyMeters);
    expect(realtime.headingDegrees, rest.headingDegrees);
    expect(realtime.speedMps, rest.speedMps);
    expect(realtime.distanceKm, rest.distanceKm);
    expect(realtime.etaMinutes, rest.etaMinutes);
    expect(rest.at, DateTime.utc(2026, 9, 13, 9));
  });
}
