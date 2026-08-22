import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/location/place_search_service.dart';

void main() {
  test('explicit city keeps fuzzy place results inside that city', () async {
    final dio = Dio()..httpClientAdapter = _PhotonStubAdapter();
    final results = await PlaceSearchService(dio: dio).search(
      'Namangan IT Park',
      language: AppLanguage.uz,
      bias: const LatLng(37.785834, -122.406417),
    );

    expect(results.map((result) => result.label), [
      'Namangan IT School',
      'Tehno Park',
    ]);
    expect(
      results.every(
        (result) => '${result.label} ${result.subtitle}'.toLowerCase().contains(
          'namangan',
        ),
      ),
      isTrue,
    );
  });
}

class _PhotonStubAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final query = options.queryParameters['q']?.toString();
    final hasBias = options.queryParameters.containsKey('lat');
    final features = switch ((query, hasBias)) {
      ('Namangan IT Park', true)
          when options.queryParameters['lat'] == 37.785834 =>
        [
          _feature(
            name: 'Tea it Up',
            city: 'Menlo Park',
            country: 'USA',
            longitude: -122.18,
            latitude: 37.45,
          ),
        ],
      ('namangan', false) => [
        _feature(
          name: 'Namangan',
          kind: 'city',
          state: 'Namangan Viloyati',
          country: 'Oʻzbekiston',
          longitude: 71.67,
          latitude: 41.00,
        ),
      ],
      ('Namangan IT Park', true) => [
        _feature(
          name: 'Namangan IT School',
          city: 'Namangan',
          state: 'Namangan Viloyati',
          country: 'Oʻzbekiston',
          longitude: 71.6401745,
          latitude: 40.9968664,
        ),
        _feature(
          name: 'Tea it Up',
          city: 'Menlo Park',
          country: 'USA',
          longitude: -122.18,
          latitude: 37.45,
        ),
        _feature(
          name: 'Tehno Park',
          city: 'Namangan',
          state: 'Namangan Viloyati',
          country: 'Oʻzbekiston',
          longitude: 71.6468395,
          latitude: 40.999492,
        ),
      ],
      _ => const <Map<String, dynamic>>[],
    };
    return ResponseBody.fromString(
      jsonEncode({'type': 'FeatureCollection', 'features': features}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _feature({
    required String name,
    required double longitude,
    required double latitude,
    String kind = 'other',
    String? city,
    String? state,
    String? country,
  }) {
    final properties = <String, dynamic>{'name': name, 'type': kind};
    if (city != null) properties['city'] = city;
    if (state != null) properties['state'] = state;
    if (country != null) properties['country'] = country;
    return {
      'type': 'Feature',
      'properties': properties,
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
    };
  }

  @override
  void close({bool force = false}) {}
}
