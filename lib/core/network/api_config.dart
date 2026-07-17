/// Central place for backend connection settings.
///
/// All API docs (see `/api/*.md`) share the same base URL and the same
/// response envelope. Keep environment-specific values here so switching
/// between staging / production is a one-line change.
class ApiConfig {
  ApiConfig._();

  /// Base URL for every request — already includes the `/api/v1` prefix, so
  /// service classes pass only the route part (e.g. `/work-radiuses`).
  static const String baseUrl = 'https://api.fixleo.com/api/v1';

  /// Swagger / OpenAPI docs, handy for reference.
  static const String docsUrl = 'https://api.fixleo.com/api/docs';

  /// Network timeouts.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
