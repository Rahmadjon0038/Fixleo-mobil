import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/locale/app_locale.dart';

/// Worldwide, search-as-you-type place lookup used by map pickers.
///
/// The map itself is rendered by Google Maps. Autocomplete uses Photon's
/// OpenStreetMap search API, so it does not require a second mobile API key or
/// restrict results to a hard-coded service region.
class PlaceSearchService {
  PlaceSearchService({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static Dio _buildDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
      headers: const {'User-Agent': 'FixLeo/1.0'},
    ),
  );

  Future<List<PlaceSearchResult>> search(
    String query, {
    required AppLanguage language,
    int limit = 5,
    LatLng? bias,
  }) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const [];

    final queryTokens = _tokens(normalized);
    final initialResults = await _queryPhoton(
      normalized,
      language: language,
      limit: 12,
      bias: bias,
      biasScale: 0.18,
    );
    final relevant = _rankRelevant(initialResults, queryTokens);
    if (relevant.any((item) => _matchesAllTokens(item, queryTokens))) {
      return relevant.take(limit).toList();
    }

    // Two-word searches such as "IT Park" have no explicit locality; their
    // current map/device position is already the best available bias.
    if (queryTokens.length < 3) return relevant.take(limit).toList();

    // A phrase such as "Namangan IT Park" can be misread by a fuzzy global
    // index as "Italian park". Detect a city/state token in the phrase, then
    // repeat the complete query with a strong bias around that locality.
    final locality = await _findExplicitLocality(
      normalized,
      language: language,
    );
    if (locality == null) return relevant.take(limit).toList();

    final localResults = await _queryPhoton(
      normalized,
      language: language,
      limit: 16,
      bias: locality.point,
      biasScale: 0,
    );
    final localMatches = _rankRelevant(localResults, queryTokens)
        .where((item) {
          return _resultTokens(item).containsAll(_tokens(locality.label));
        })
        .toList(growable: false);
    return localMatches.take(limit).toList(growable: false);
  }

  Future<List<PlaceSearchResult>> _queryPhoton(
    String query, {
    required AppLanguage language,
    required int limit,
    LatLng? bias,
    double? biasScale,
  }) async {
    final parameters = <String, dynamic>{'q': query, 'limit': limit};
    if (bias != null) {
      parameters.addAll({
        'lat': bias.latitude,
        'lon': bias.longitude,
        'zoom': 11,
      });
      if (biasScale != null) {
        parameters['location_bias_scale'] = biasScale;
      }
    }
    final response = await _dio.get(
      'https://photon.komoot.io/api/',
      queryParameters: parameters,
      options: Options(headers: {'Accept-Language': language.name}),
    );

    final data = response.data;
    if (data is! Map) return const [];
    final features = data['features'];
    if (features is! List) return const [];

    final results = <PlaceSearchResult>[];
    for (final raw in features) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final geometry = item['geometry'];
      final properties = item['properties'];
      if (geometry is! Map || properties is! Map) continue;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final longitude = _toDouble(coordinates[0]);
      final latitude = _toDouble(coordinates[1]);
      if (latitude == null || longitude == null) continue;

      final values = Map<String, dynamic>.from(properties);
      final name = _text(values['name']);
      final street = _text(values['street']);
      final houseNumber = _text(values['housenumber']);
      final streetAddress = [
        ?street,
        ?houseNumber,
      ].where((value) => value.isNotEmpty).join(' ');
      final label = name ?? (streetAddress.isEmpty ? null : streetAddress);
      if (label == null) continue;

      final subtitleParts = <String>[];
      void addPart(dynamic raw) {
        final value = _text(raw);
        if (value == null || value == label || subtitleParts.contains(value)) {
          return;
        }
        subtitleParts.add(value);
      }

      if (streetAddress.isNotEmpty && streetAddress != label) {
        addPart(streetAddress);
      }
      addPart(values['district']);
      addPart(values['city']);
      addPart(values['county']);
      addPart(values['state']);
      addPart(values['country']);

      results.add(
        PlaceSearchResult(
          point: LatLng(latitude, longitude),
          label: label,
          subtitle: subtitleParts.take(4).join(', '),
          kind: _text(values['type']),
        ),
      );
    }
    return results;
  }

  Future<PlaceSearchResult?> _findExplicitLocality(
    String query, {
    required AppLanguage language,
  }) async {
    final words = _tokens(query).where((word) => word.length >= 4).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (words.isEmpty) return null;
    final candidates = words.take(3);
    const localityKinds = {
      'city',
      'locality',
      'district',
      'county',
      'state',
      'country',
    };

    for (final candidate in candidates) {
      final matches = await _queryPhoton(
        candidate,
        language: language,
        limit: 5,
      );
      for (final match in matches) {
        final kind = match.kind?.toLowerCase();
        if (kind == null || !localityKinds.contains(kind)) continue;
        if (_tokens(match.label).contains(candidate)) return match;
      }
    }
    return null;
  }

  List<PlaceSearchResult> _rankRelevant(
    List<PlaceSearchResult> results,
    Set<String> queryTokens,
  ) {
    if (queryTokens.isEmpty) return results;
    final scored = <({PlaceSearchResult item, int score})>[];
    final minimumMatches = queryTokens.length > 1 ? 2 : 1;
    for (final result in results) {
      final resultTokens = _resultTokens(result);
      final score = queryTokens.where((queryToken) {
        return resultTokens.any(
          (resultToken) =>
              resultToken == queryToken ||
              (queryToken.length >= 3 && resultToken.startsWith(queryToken)),
        );
      }).length;
      if (score >= minimumMatches) scored.add((item: result, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  bool _matchesAllTokens(PlaceSearchResult result, Set<String> queryTokens) {
    final resultTokens = _resultTokens(result);
    return queryTokens.every((queryToken) {
      return resultTokens.any(
        (resultToken) =>
            resultToken == queryToken ||
            (queryToken.length >= 3 && resultToken.startsWith(queryToken)),
      );
    });
  }

  Set<String> _resultTokens(PlaceSearchResult result) =>
      _tokens('${result.label} ${result.subtitle}');

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9\u0400-\u04FFʻʼ’]+'))
      .where((word) => word.length >= 2)
      .toSet();

  double? _toDouble(dynamic value) => switch (value) {
    num number => number.toDouble(),
    _ => double.tryParse(value?.toString() ?? ''),
  };

  String? _text(dynamic raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.point,
    required this.label,
    required this.subtitle,
    this.kind,
  });

  final LatLng point;
  final String label;
  final String subtitle;
  final String? kind;
}
