import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fixleo/core/network/api_client.dart';

class _SuccessAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'success': true,
      'data': {'token': 'server-secret-token'},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('debug HTTP logs never expose payloads or query parameters', () async {
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.test',
        validateStatus: (_) => true,
        contentType: Headers.jsonContentType,
      ),
    )..httpClientAdapter = _SuccessAdapter();
    final api = ApiClient(dio: dio, refreshDio: dio);

    await api.post(
      '/clients/me/device-tokens?installation=private-installation',
      body: {'token': 'private-device-token', 'password': 'private-password'},
    );

    final output = messages.join('\n');
    expect(output, contains('POST https://api.test/clients/me/device-tokens'));
    expect(output, isNot(contains('private-device-token')));
    expect(output, isNot(contains('private-password')));
    expect(output, isNot(contains('private-installation')));
    expect(output, isNot(contains('server-secret-token')));
  });
}
