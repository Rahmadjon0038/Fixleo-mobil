import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/core/realtime/call_ice_config.dart';

void main() {
  test('parses authenticated STUN and TURN fallback servers', () {
    final config = CallIceConfiguration.fromApi({
      'iceServers': [
        {
          'urls': ['stun:stun.l.google.com:19302'],
        },
        {
          'urls': [
            'turn:turn.fixleo.com:3478?transport=udp',
            'turn:turn.fixleo.com:3478?transport=tcp',
            'turns:turn.fixleo.com:5349?transport=tcp',
          ],
          'username': '1787156400:client-42',
          'credential': 'temporary-credential',
        },
      ],
      'expiresAt': '2026-08-19T12:00:00.000Z',
    });

    expect(config.iceServers, hasLength(2));
    expect(config.iceServers.last['username'], '1787156400:client-42');
    expect(config.iceServers.last['urls'], contains(startsWith('turns:')));
  });

  test('rejects a TURN response without temporary credentials', () {
    expect(
      () => CallIceConfiguration.fromApi({
        'iceServers': [
          {
            'urls': ['turn:turn.fixleo.com:3478?transport=udp'],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('provides STUN-only fallback for a temporarily unavailable backend', () {
    final config = CallIceConfiguration.fallback
        .toPeerConnectionConfiguration();
    expect(config['iceServers'], hasLength(1));
    expect(
      (config['iceServers'] as List).first['urls'],
      contains('stun:stun.l.google.com:19302'),
    );
  });
}
