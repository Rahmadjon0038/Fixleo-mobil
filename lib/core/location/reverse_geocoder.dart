import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Worldwide reverse-geocoding helper around OpenStreetMap Nominatim.
///
/// Google Maps renders the map while this independent service converts the
/// selected coordinate into a readable address.
class ReverseGeocoder {
  ReverseGeocoder({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static Dio _buildDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
      headers: const {'User-Agent': 'FixLeo/1.0'},
    ),
  );

  Future<ReverseGeocodeResult?> resolve(LatLng point) async {
    final response = await _dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'jsonv2',
        'lat': point.latitude,
        'lon': point.longitude,
        'zoom': 18,
        'addressdetails': 1,
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return null;

    final address = data['address'];
    final addressMap = address is Map
        ? Map<String, dynamic>.from(address)
        : const <String, dynamic>{};
    final label =
        _labelFromAddress(addressMap) ??
        _firstChunk(data['display_name'] as String?);
    final subtitle = _subtitleFromAddress(addressMap, data['display_name']);

    if (label == null && subtitle == null) return null;

    return ReverseGeocodeResult(
      label: label ?? _coordinates(point),
      subtitle: subtitle ?? _coordinates(point),
    );
  }

  String _coordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

  String? _labelFromAddress(Map<String, dynamic> address) {
    const keys = [
      'neighbourhood',
      'suburb',
      'city_district',
      'city',
      'town',
      'village',
      'municipality',
    ];

    final parts = <String>[];
    for (final key in keys) {
      final raw = address[key];
      final value = raw?.toString();
      if (value != null) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          parts.add(trimmed);
          if (parts.length == 2) break;
        }
      }
    }

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? _firstChunk(String? text) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return null;
    return value.split(',').first.trim();
  }

  String? _subtitleFromAddress(
    Map<String, dynamic> address,
    dynamic displayName,
  ) {
    const keys = [
      'house_number',
      'road',
      'pedestrian',
      'residential',
      'city_district',
      'suburb',
      'city',
      'town',
      'village',
      'county',
      'state',
    ];

    for (final key in keys) {
      final raw = address[key];
      final value = raw?.toString();
      if (value != null) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }

    final display = displayName?.toString().trim();
    if (display != null && display.isNotEmpty) {
      final pieces = display.split(',');
      if (pieces.length > 1) {
        return pieces[1].trim();
      }
      return display;
    }

    return null;
  }
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({required this.label, required this.subtitle});

  final String label;
  final String subtitle;
}
