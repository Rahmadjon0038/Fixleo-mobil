import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/auth_session.dart';

/// Thin wrapper around [Dio] that knows how to talk to the Fixleo backend.
///
/// Every endpoint shares the same contract (see `api/Backend Config for client.md`):
///   * success → `{ "success": true, "message": "...", "data": <payload> }`
///   * failure → `{ "success": false, "message": "...", "statusCode": ... }`
///
/// The request methods here unwrap that envelope and return only the `data`
/// payload, throwing an [ApiException] (already-localized `message`, plus any
/// per-field `errors[]`) on any non-success response or transport error. They
/// also:
  ///   * send `Accept-Language` from [LocaleController] so backend messages come
  ///     back in the user's language (uz / ru / en);
///   * attach `Authorization: Bearer <accessToken>` from [AuthSession];
///   * on a `401`, transparently refresh the access token once (using the
///     role-appropriate `/refresh` endpoint) and retry the request.
class ApiClient {
  ApiClient({Dio? dio, AuthSession? session})
      : _session = session ?? AuthSession.instance,
        _dio = dio ?? _buildDio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept-Language'] = _acceptLanguage;
          if (_session.hasToken) {
            options.headers['Authorization'] = 'Bearer ${_session.accessToken}';
          }
          handler.next(options);
        },
      ),
    );

    // In debug builds, print every request + response/error to the console so
    // you can confirm the app is really hitting the backend (and see why a call
    // fell back to local data). Stripped from release builds.
    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('➡️  ${options.method} ${options.uri}');
            if (options.data != null) {
              if (options.data is FormData) {
                final formData = options.data as FormData;
                debugPrint('    form fields: ${formData.fields}');
                debugPrint(
                    '    form files: ${formData.files.map((f) => f.key).toList()}');
              } else {
                debugPrint('    body: ${options.data}');
              }
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
                '⬅️  ${response.statusCode} ${response.requestOptions.uri}');
            if (response.statusCode != null && response.statusCode! >= 400) {
              debugPrint('    response body: ${response.data}');
            }
            handler.next(response);
          },
          onError: (e, handler) {
            debugPrint(
                '❌  ${e.response?.statusCode ?? '—'} ${e.requestOptions.uri}  ${e.message}');
            if (e.response?.data != null) {
              debugPrint('    error body: ${e.response?.data}');
            }
            handler.next(e);
          },
        ),
      );
    }
  }

  static Dio _buildDio() => Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          // Let our own logic decide what counts as an error so we can read the
          // structured error envelope on 4xx/5xx responses.
          validateStatus: (_) => true,
          contentType: Headers.jsonContentType,
        ),
      );

  /// Shared, app-wide instance.
  static final ApiClient instance = ApiClient();

  final Dio _dio;
  final AuthSession _session;

  String get _acceptLanguage => switch (LocaleController.language.value) {
        AppLanguage.uz => 'uz',
        AppLanguage.ru => 'ru',
        AppLanguage.en => 'en',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  /// Uploads [formData] as `multipart/form-data` (e.g. KYC document upload).
  Future<dynamic> postMultipart(String path, FormData formData) =>
      _send(() => _dio.post(path, data: formData));

  /// Runs [request], validates the envelope and returns the `data` payload.
  /// Retries once after a successful token refresh on a `401`.
  Future<dynamic> _send(
    Future<Response<dynamic>> Function() request, {
    bool allowRefresh = true,
  }) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['success'] == false) {
        throw ApiException.fromEnvelope(data, fallbackStatus: e.response?.statusCode);
      }
      if (kDebugMode) {
        debugPrint('Network failure: ${e.message}');
        if (e.error != null) {
          debugPrint('Underlying error: ${e.error}');
        }
      }
      throw ApiException(
        message: _friendlyNetworkError(e),
        statusCode: e.response?.statusCode,
        isNetworkError: true,
      );
    }

    // Access token expired — try a single transparent refresh, then retry.
    if (response.statusCode == 401 && allowRefresh && _session.refreshToken != null) {
      if (await _tryRefresh()) {
        return _send(request, allowRefresh: false);
      }
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true) {
        return data['data'];
      }
      if (kDebugMode) {
        debugPrint('    api error envelope: $data');
        final errors = data['errors'];
        if (errors is List) {
          for (final item in errors) {
            debugPrint('    validation: $item');
          }
        }
      }
      throw ApiException.fromEnvelope(data, fallbackStatus: response.statusCode);
    }

    throw ApiException(
      message: 'Unexpected response from server',
      statusCode: response.statusCode,
    );
  }

  String _friendlyNetworkError(DioException e) {
    final lang = LocaleController.language.value;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return tr(
          lang,
          'Ulanish vaqti tugadi. Qayta urinib koʻring.',
          'Время соединения истекло. Попробуйте еще раз.',
          'Connection timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return tr(
          lang,
          'Serverga ulanib boʻlmadi. Internet aloqangizni tekshiring.',
          'Не удается подключиться к серверу. Проверьте интернет-соединение.',
          'Cannot reach the server. Check your internet connection.',
        );
      case DioExceptionType.badCertificate:
        return tr(
          lang,
          'Xavfsiz ulanish amalga oshmadi.',
          'Не удалось установить безопасное соединение.',
          'Secure connection failed.',
        );
      case DioExceptionType.cancel:
        return tr(
          lang,
          'Soʻrov bekor qilindi.',
          'Запрос был отменён.',
          'Request was cancelled.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    return tr(
      lang,
      'Tarmoq xatosi. Qayta urinib koʻring.',
      'Ошибка сети. Попробуйте еще раз.',
      'Network error. Please try again.',
    );
  }

  /// Exchanges the stored refresh token for a fresh token pair using the
  /// role-appropriate endpoint. Returns false (and clears the session) if the
  /// refresh token is itself invalid/expired/revoked.
  Future<bool> _tryRefresh() async {
    final role = _session.role;
    final refreshToken = _session.refreshToken;
    if (role == null || refreshToken == null) return false;

    final path = switch (role) {
      AuthRole.client => '/clients/auth/refresh',
      AuthRole.master => '/masters/auth/refresh',
      AuthRole.admin => '/auth/refresh',
    };

    try {
      // Bare call (no auth header, no recursion) on the same Dio.
      final res = await _dio.post(
        path,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Accept-Language': _acceptLanguage}),
      );
      final data = res.data;
      if (res.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['success'] == true) {
        final tokens = data['data'] as Map<String, dynamic>;
        await _session.updateTokens(
          accessToken: tokens['accessToken'] as String,
          refreshToken: tokens['refreshToken'] as String,
        );
        return true;
      }
    } on DioException {
      // fall through
    }

    // Refresh token no longer valid — force a re-login.
    await _session.clear();
    return false;
  }
}
