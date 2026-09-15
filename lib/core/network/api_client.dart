import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/network/api_config.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/auth_session.dart';
import 'package:fixleo/core/network/installation_identity.dart';

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
  ApiClient({Dio? dio, Dio? refreshDio, AuthSession? session})
    : _session = session ?? AuthSession.instance,
      _dio = dio ?? _buildDio(),
      _refreshDio = refreshDio ?? _buildDio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Accept-Language'] = _acceptLanguage;
          final installationId = InstallationIdentity.value;
          if (installationId != null) {
            options.headers['X-Fixleo-Installation-Id'] = installationId;
          }

          // Refresh just before JWT expiry. Besides avoiding a visible 401,
          // this also makes multipart requests safe: streamed upload bodies
          // cannot always be replayed after the server has rejected them.
          if (!_isPublicAuthRequest(options.path) &&
              _session.hasToken &&
              _session.accessTokenExpiresWithin(const Duration(seconds: 45))) {
            try {
              final refreshed = await refreshTokens();
              if (!refreshed) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.cancel,
                    error: SessionExpiredException(
                      message: _sessionExpiredMessage,
                    ),
                  ),
                );
              }
            } on ApiException catch (error) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.unknown,
                  error: error,
                ),
              );
            }
          }

          if (_session.hasToken) {
            options.headers['Authorization'] = 'Bearer ${_session.accessToken}';
          }
          handler.next(options);
        },
      ),
    );

    // In debug builds, print only request metadata. Payloads, query parameters
    // and response bodies can contain OTPs, card data, chat text, addresses or
    // push tokens and must never leak into device/CI logs. Stripped from
    // release builds.
    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('➡️  ${options.method} ${_safeDebugUri(options.uri)}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '⬅️  ${response.statusCode} '
              '${_safeDebugUri(response.requestOptions.uri)}',
            );
            handler.next(response);
          },
          onError: (e, handler) {
            debugPrint(
              '❌  ${e.response?.statusCode ?? '—'} '
              '${_safeDebugUri(e.requestOptions.uri)}  ${e.type.name}',
            );
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
  final Dio _refreshDio;
  final AuthSession _session;
  Future<bool>? _refreshInFlight;

  String get _acceptLanguage => switch (LocaleController.language.value) {
    AppLanguage.uz => 'uz',
    AppLanguage.ru => 'ru',
    AppLanguage.en => 'en',
  };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  static String _safeDebugUri(Uri uri) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return '${uri.origin}${uri.path}';
    }
    return uri.path;
  }

  Future<dynamic> post(String path, {Object? body, String? idempotencyKey}) =>
      _send(
        () => _dio.post(
          path,
          data: body,
          options: Options(headers: {'Idempotency-Key': ?idempotencyKey}),
        ),
      );

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  /// Uploads [formData] as `multipart/form-data` (e.g. KYC document upload).
  ///
  /// [onSendProgress] lets screens render per-file progress instead of a single
  /// indefinite spinner while a large media file is in flight.
  Future<dynamic> postMultipart(
    String path,
    FormData formData, {
    ProgressCallback? onSendProgress,
  }) => _send(
    () => _dio.post(path, data: formData, onSendProgress: onSendProgress),
  );

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
      final underlying = e.error;
      if (underlying is ApiException) {
        throw underlying;
      }
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['success'] == false) {
        throw ApiException.fromEnvelope(
          data,
          fallbackStatus: e.response?.statusCode,
        );
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

    // Access token expired — try one coordinated transparent refresh, then
    // retry. Authentication endpoints are intentionally excluded: an invalid
    // OTP/password is its own 401 and must never refresh a stale login.
    if (response.statusCode == 401 &&
        allowRefresh &&
        !_isPublicAuthRequest(response.requestOptions.path)) {
      if (!_session.canRefresh) {
        await _session.expire();
        throw SessionExpiredException(message: _sessionExpiredMessage);
      }

      // A different request may already have refreshed while this one was in
      // flight. If so, retry with the current token instead of rotating again.
      if (!_requestUsedCurrentAccessToken(response) || await refreshTokens()) {
        return _send(request, allowRefresh: false);
      }

      throw SessionExpiredException(message: _sessionExpiredMessage);
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true) {
        return data['data'];
      }
      throw ApiException.fromEnvelope(
        data,
        fallbackStatus: response.statusCode,
      );
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

  /// Public refresh for the socket layer: live sockets can't ride the REST
  /// 401 interceptor, so on `token_expired` they refresh here first and then
  /// reconnect with the fresh access token.
  Future<bool> refreshTokens() {
    final active = _refreshInFlight;
    if (active != null) return active;

    final refresh = _tryRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
  }

  /// Exchanges the stored refresh token for a fresh token pair using the
  /// role-appropriate endpoint. A temporary network/backend failure preserves
  /// the login; only a definitive invalid/expired/revoked response expires it.
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
      // Dedicated bare Dio: no access-token interceptor and no refresh
      // recursion while we are exchanging the refresh token itself.
      final res = await _refreshDio.post(
        path,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Accept-Language': _acceptLanguage}),
      );
      final data = res.data;
      if (res.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['success'] == true) {
        final rawTokens = data['data'];
        if (rawTokens is! Map) {
          throw ApiException(
            message: 'Unexpected response from server',
            statusCode: res.statusCode,
          );
        }
        final tokens = Map<String, dynamic>.from(rawTokens);
        final access = tokens['accessToken'];
        final nextRefresh = tokens['refreshToken'];
        if (access is! String ||
            access.isEmpty ||
            nextRefresh is! String ||
            nextRefresh.isEmpty) {
          throw ApiException(
            message: 'Unexpected response from server',
            statusCode: res.statusCode,
          );
        }

        // Ignore a late refresh response after logout/new login. It belongs to
        // the token snapshot captured at the beginning of this exchange.
        if (_session.role != role || _session.refreshToken != refreshToken) {
          return _session.hasToken;
        }
        await _session.updateTokens(
          accessToken: access,
          refreshToken: nextRefresh,
        );
        return true;
      }

      if (res.statusCode == 400 ||
          res.statusCode == 401 ||
          res.statusCode == 403) {
        // If another login/refresh replaced this token while the request was
        // in flight, never erase that newer valid session.
        if (_session.role == role && _session.refreshToken == refreshToken) {
          await _session.expire();
        }
        return false;
      }

      if (data is Map<String, dynamic> && data['success'] == false) {
        throw ApiException.fromEnvelope(data, fallbackStatus: res.statusCode);
      }
      throw ApiException(
        message: 'Unexpected response from server',
        statusCode: res.statusCode,
      );
    } on DioException catch (error) {
      // Offline/timeout is not proof that a refresh token is bad. Preserve it
      // so the next request can retry after connectivity returns.
      throw ApiException(
        message: _friendlyNetworkError(error),
        statusCode: error.response?.statusCode,
        isNetworkError: true,
      );
    }
  }

  bool _requestUsedCurrentAccessToken(Response<dynamic> response) {
    final current = _session.accessToken;
    if (current == null) return false;
    return response.requestOptions.headers['Authorization'] ==
        'Bearer $current';
  }

  bool _isPublicAuthRequest(String path) {
    final normalized = Uri.parse(path).path;
    return normalized == '/auth/login' ||
        normalized == '/auth/refresh' ||
        normalized == '/auth/logout' ||
        normalized == '/clients/auth/send-otp' ||
        normalized == '/clients/auth/resend-otp' ||
        normalized == '/clients/auth/verify-otp' ||
        normalized == '/clients/auth/register' ||
        normalized == '/clients/auth/refresh' ||
        normalized == '/clients/auth/logout' ||
        normalized == '/masters/auth/send-otp' ||
        normalized == '/masters/auth/resend-otp' ||
        normalized == '/masters/auth/verify-otp' ||
        normalized == '/masters/auth/refresh' ||
        normalized == '/masters/auth/logout';
  }

  String get _sessionExpiredMessage => tr(
    LocaleController.language.value,
    'Kirish muddati tugadi. Qayta kiring.',
    'Сеанс завершён. Войдите снова.',
    'Your session has expired. Please sign in again.',
  );
}
