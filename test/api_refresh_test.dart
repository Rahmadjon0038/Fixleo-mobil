import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/auth_session.dart';

typedef _Responder = Future<ResponseBody> Function(RequestOptions options);

class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this.respond);

  final _Responder respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Responder responder) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test',
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
    ),
  );
  dio.httpClientAdapter = _TestAdapter(responder);
  return dio;
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _jwtExpiringAt(DateTime time) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({'exp': time.toUtc().millisecondsSinceEpoch ~/ 1000}),
    ),
  );
  return '$header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = AuthSession.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await session.load();
  });

  tearDown(() async {
    await session.clear();
  });

  test('parallel 401 responses share one rotating refresh request', () async {
    final oldAccess = _jwtExpiringAt(
      DateTime.now().add(const Duration(hours: 1)),
    );
    final newAccess = _jwtExpiringAt(
      DateTime.now().add(const Duration(hours: 2)),
    );
    await session.start(
      role: AuthRole.client,
      accessToken: oldAccess,
      refreshToken: 'refresh-old',
    );

    var refreshCalls = 0;
    final api = ApiClient(
      session: session,
      dio: _dio((options) async {
        if (options.path == '/protected') {
          if (options.headers['Authorization'] == 'Bearer $newAccess') {
            return _json(200, {
              'success': true,
              'data': {'ok': true},
            });
          }
          return _json(401, {
            'success': false,
            'statusCode': 401,
            'message': 'Access token expired',
          });
        }
        return _json(404, {'success': false, 'statusCode': 404});
      }),
      refreshDio: _dio((options) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _json(200, {
          'success': true,
          'data': {'accessToken': newAccess, 'refreshToken': 'refresh-new'},
        });
      }),
    );

    final results = await Future.wait([
      api.get('/protected'),
      api.get('/protected'),
    ]);

    expect(refreshCalls, 1);
    expect(results, [
      {'ok': true},
      {'ok': true},
    ]);
    expect(session.accessToken, newAccess);
    expect(session.refreshToken, 'refresh-new');
  });

  test('temporary refresh network failure does not erase the login', () async {
    final access = _jwtExpiringAt(DateTime.now().add(const Duration(hours: 1)));
    await session.start(
      role: AuthRole.master,
      accessToken: access,
      refreshToken: 'keep-me',
    );

    final api = ApiClient(
      session: session,
      dio: _dio(
        (_) async => _json(401, {
          'success': false,
          'statusCode': 401,
          'message': 'Access token expired',
        }),
      ),
      refreshDio: _dio((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      }),
    );

    await expectLater(
      api.get('/protected'),
      throwsA(
        isA<ApiException>().having((e) => e.isNetworkError, 'network', isTrue),
      ),
    );
    expect(session.role, AuthRole.master);
    expect(session.accessToken, access);
    expect(session.refreshToken, 'keep-me');
  });

  test(
    'invalid refresh expires the session and emits a navigation event',
    () async {
      final access = _jwtExpiringAt(
        DateTime.now().add(const Duration(hours: 1)),
      );
      await session.start(
        role: AuthRole.client,
        accessToken: access,
        refreshToken: 'revoked',
      );
      final expirationBefore = session.expirationEvents.value;

      final api = ApiClient(
        session: session,
        dio: _dio(
          (_) async => _json(401, {
            'success': false,
            'statusCode': 401,
            'message': 'Access token expired',
          }),
        ),
        refreshDio: _dio(
          (_) async => _json(401, {
            'success': false,
            'statusCode': 401,
            'message': 'Refresh token invalid',
          }),
        ),
      );

      await expectLater(
        api.get('/protected'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(session.isLoggedIn, isFalse);
      expect(session.expirationEvents.value, expirationBefore + 1);
    },
  );

  test(
    'an almost-expired access token refreshes before protected request',
    () async {
      final oldAccess = _jwtExpiringAt(
        DateTime.now().add(const Duration(seconds: 10)),
      );
      final newAccess = _jwtExpiringAt(
        DateTime.now().add(const Duration(hours: 1)),
      );
      await session.start(
        role: AuthRole.client,
        accessToken: oldAccess,
        refreshToken: 'refresh-old',
      );

      var protectedCalls = 0;
      var refreshCalls = 0;
      final api = ApiClient(
        session: session,
        dio: _dio((options) async {
          protectedCalls++;
          expect(options.headers['Authorization'], 'Bearer $newAccess');
          return _json(200, {'success': true, 'data': 'ok'});
        }),
        refreshDio: _dio((_) async {
          refreshCalls++;
          return _json(200, {
            'success': true,
            'data': {'accessToken': newAccess, 'refreshToken': 'refresh-new'},
          });
        }),
      );

      await expectLater(api.get('/protected'), completion('ok'));
      expect(refreshCalls, 1);
      expect(protectedCalls, 1);
    },
  );
}
