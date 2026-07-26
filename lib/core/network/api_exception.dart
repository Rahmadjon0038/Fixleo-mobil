/// A single field-level validation error from a `400` response's `errors[]`.
///
/// `message` is already localized (per `Accept-Language`); show it under the
/// matching form field.
class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;

  factory FieldError.fromJson(Map<String, dynamic> json) => FieldError(
    field: json['field']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
  );
}

/// A typed error built from the backend's standard error envelope:
///
/// ```json
/// { "success": false, "message": "...", "statusCode": 404,
///   "path": "...", "timestamp": "...", "requestId": "...",
///   "errors": [ { "field": "phone", "message": "..." } ] }
/// ```
///
/// `message` is already translated by the backend according to the
/// `Accept-Language` header we send, so it can be shown to the user directly.
/// See `api/Backend Config for client.md`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.path,
    this.requestId,
    this.errors = const [],
    this.isNetworkError = false,
  });

  /// Human-readable, already-localized message from the backend.
  final String message;

  /// HTTP status code (e.g. 400, 401, 404, 409, 429). Null for transport
  /// errors that never reached the server.
  final int? statusCode;

  /// Request path that failed (from the error envelope).
  final String? path;

  /// Correlation id (matches the `X-Request-Id` response header) — useful for
  /// support and log lookups.
  final String? requestId;

  /// Per-field validation errors — only present on `400` responses.
  final List<FieldError> errors;

  /// True when the request never got a server response (no connection,
  /// timeout, etc.) rather than a structured backend error.
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isRateLimited => statusCode == 429;
  bool get isValidation => statusCode == 400 && errors.isNotEmpty;

  /// First validation message for [field], if any (for binding under inputs).
  String? errorFor(String field) {
    for (final e in errors) {
      if (e.field == field) return e.message;
    }
    return null;
  }

  /// Seconds to wait, parsed from a `429` message like
  /// "Too many requests — try again in 47s". Null when not found.
  int? get retryAfterSeconds {
    final match = RegExp(r'(\d+)\s*s').firstMatch(message);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Builds an exception from a decoded error-envelope map.
  factory ApiException.fromEnvelope(
    Map<String, dynamic> json, {
    int? fallbackStatus,
  }) {
    final rawErrors = json['errors'];
    return ApiException(
      message: (json['message'] as String?) ?? 'Unexpected error',
      statusCode: (json['statusCode'] as num?)?.toInt() ?? fallbackStatus,
      path: json['path'] as String?,
      requestId: json['requestId'] as String?,
      errors: rawErrors is List
          ? rawErrors
                .map((e) => FieldError.fromJson(e as Map<String, dynamic>))
                .toList(growable: false)
          : const [],
    );
  }

  @override
  String toString() =>
      'ApiException($statusCode): $message${requestId != null ? ' [$requestId]' : ''}';
}

/// The refresh token is expired, revoked or otherwise unusable. The root app
/// observes the corresponding [AuthSession] event and returns to login, while
/// callers can distinguish this from a normal endpoint-level 401.
class SessionExpiredException extends ApiException {
  const SessionExpiredException({required super.message})
    : super(statusCode: 401);
}
