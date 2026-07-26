import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/realtime/call_service.dart';

String _jwt({required int sub}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': sub,
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }),
    ),
  );
  return '$header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = AuthSession.instance;
  final calls = CallService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    calls.disconnect();
    await session.load();
  });

  tearDown(() async {
    calls.disconnect();
    await session.clear();
  });

  test('logout removes the old account call socket', () async {
    await session.start(
      role: AuthRole.client,
      accessToken: _jwt(sub: 41),
      refreshToken: 'refresh-client',
    );
    calls.syncForCurrentSession();
    expect(calls.hasSignallingSocket, isTrue);
    expect(calls.connectedKind, 'client');
    expect(calls.connectedOwnerId, 41);

    await session.clear();
    calls.syncForCurrentSession();
    expect(calls.hasSignallingSocket, isFalse);
    expect(calls.connectedKind, isNull);
    expect(calls.connectedOwnerId, isNull);
  });

  test('same-role account replacement cannot reuse the old identity', () async {
    await session.start(
      role: AuthRole.master,
      accessToken: _jwt(sub: 10),
      refreshToken: 'refresh-first',
    );
    calls.syncForCurrentSession();
    expect(calls.connectedOwnerId, 10);

    await session.start(
      role: AuthRole.master,
      accessToken: _jwt(sub: 11),
      refreshToken: 'refresh-second',
    );
    calls.syncForCurrentSession();
    expect(calls.hasSignallingSocket, isTrue);
    expect(calls.connectedKind, 'master');
    expect(calls.connectedOwnerId, 11);
  });
}
