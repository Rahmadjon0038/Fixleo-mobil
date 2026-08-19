/// Validated WebRTC ICE configuration received from the authenticated backend.
/// Coturn credentials are intentionally runtime-only and are never compiled
/// into the APK/IPA.
class CallIceConfiguration {
  CallIceConfiguration._(this.iceServers);

  static final fallback = CallIceConfiguration._([
    {
      'urls': ['stun:stun.l.google.com:19302'],
    },
  ]);

  final List<Map<String, dynamic>> iceServers;

  factory CallIceConfiguration.fromApi(Object? data) {
    if (data is! Map) {
      throw const FormatException('ICE configuration must be an object');
    }
    final rawServers = data['iceServers'];
    if (rawServers is! List) {
      throw const FormatException('ICE servers must be a list');
    }

    final servers = <Map<String, dynamic>>[];
    var hasTurn = false;
    for (final rawServer in rawServers) {
      if (rawServer is! Map) continue;
      final urls = _normalizeUrls(rawServer['urls']);
      if (urls.isEmpty) continue;

      final usesTurn = urls.any(
        (url) => url.startsWith('turn:') || url.startsWith('turns:'),
      );
      final username = rawServer['username'];
      final credential = rawServer['credential'];
      if (usesTurn &&
          (username is! String ||
              username.isEmpty ||
              credential is! String ||
              credential.isEmpty)) {
        continue;
      }

      servers.add({
        'urls': urls,
        if (username is String && username.isNotEmpty) 'username': username,
        if (credential is String && credential.isNotEmpty)
          'credential': credential,
      });
      hasTurn = hasTurn || usesTurn;
    }

    if (servers.isEmpty || !hasTurn) {
      throw const FormatException(
        'ICE configuration has no usable TURN server',
      );
    }
    return CallIceConfiguration._(servers);
  }

  Map<String, dynamic> toPeerConnectionConfiguration() => {
    'iceServers': iceServers,
  };

  static List<String> _normalizeUrls(Object? raw) {
    final values = switch (raw) {
      String value => <Object?>[value],
      List values => values,
      _ => const <Object?>[],
    };
    return values
        .whereType<String>()
        .map((url) => url.trim())
        .where(
          (url) =>
              url.startsWith('stun:') ||
              url.startsWith('stuns:') ||
              url.startsWith('turn:') ||
              url.startsWith('turns:'),
        )
        .toList(growable: false);
  }
}
